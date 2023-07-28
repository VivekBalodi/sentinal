locals {
  default_composer_cmek = "composer-cmek6"
  branch_composer_cmek  = "${local.default_composer_cmek}-${substr(random_id.id.hex, 0, 4)}"
  composer_cmek         = var.branchname != "release" ? local.branch_composer_cmek : local.default_composer_cmek
}

data "google_project" "composer-cmek" {
}

resource "google_project_service" "enable_composer_api" {
  project                    = var.project
  service                    = "composer.googleapis.com"
  disable_dependent_services = true
  disable_on_destroy         = false
  provisioner "local-exec" {
    command = "sleep 60"
  }
}

resource "google_project_service" "enable_cloudbilling_api" {
  project                    = var.project
  service                    = "cloudbilling.googleapis.com"
  disable_dependent_services = true
  disable_on_destroy         = false
  provisioner "local-exec" {
    command = "sleep 60"
  }
}

resource "google_project_service" "enable_artifactregistry_api" {
  project                    = var.project
  service                    = "artifactregistry.googleapis.com"
  disable_dependent_services = true
  disable_on_destroy         = false
  provisioner "local-exec" {
    command = "sleep 60"
  }
}

data "google_composer_image_versions" "all" {
  region = "us-central1"
}

resource "google_kms_key_ring" "composer-cmek-ring" {
  name     = local.composer_cmek
  location = var.region
}

resource "google_kms_crypto_key" "composer-cmek-key" {
  depends_on = [google_kms_key_ring.composer-cmek-ring]
  name       = local.composer_cmek
  key_ring   = google_kms_key_ring.composer-cmek-ring.id
}

resource "google_service_account" "composer-cmek-servacc" {
  account_id = local.composer_cmek
}

resource "google_project_service_identity" "composer_sa" {
  provider = google-beta
  project  = var.project
  service  = "composer.googleapis.com"
}

resource "google_project_service_identity" "artifactregistry_sa" {
  provider = google-beta
  project  = var.project
  service  = "artifactregistry.googleapis.com"
}

resource "google_project_service_identity" "container_sa" {
  provider = google-beta
  project  = var.project
  service  = "container.googleapis.com"
}

data "google_storage_project_service_account" "storage_sa" {}

resource "google_project_service_identity" "pubsub_sa" {
  provider = google-beta
  project  = var.project
  service  = "pubsub.googleapis.com"
}

resource "google_kms_crypto_key_iam_binding" "composer-cmek-servacc" {
  crypto_key_id = google_kms_crypto_key.composer-cmek-key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"

  members = [
    "serviceAccount:${google_service_account.composer-cmek-servacc.email}",
    "serviceAccount:${google_project_service_identity.composer_sa.email}",
    "serviceAccount:${google_project_service_identity.artifactregistry_sa.email}",
    "serviceAccount:${google_project_service_identity.container_sa.email}",
    "serviceAccount:${google_project_service_identity.pubsub_sa.email}",
    "serviceAccount:${data.google_storage_project_service_account.storage_sa.email_address}",
    "serviceAccount:service-${data.google_project.composer-cmek.number}@compute-system.iam.gserviceaccount.com",
  ]
}

resource "google_project_iam_member" "composer-cmek-servacc-02" {
  role   = "roles/composer.worker"
  member = "serviceAccount:${google_service_account.composer-cmek-servacc.email}"
}

resource "google_composer_environment" "composer_cmek" {
  depends_on = [
    google_project_service.enable_composer_api,
    google_project_service.enable_cloudbilling_api,
    google_kms_crypto_key_iam_binding.composer-cmek-servacc,
    google_project_iam_member.composer-cmek-servacc-02,
  ]
  provider = google-beta
  name     = local.composer_cmek
  region   = "us-central1"
  config {
    software_config {
      image_version = data.google_composer_image_versions.all.image_versions[0].image_version_id
    }
    node_count = 3
    private_environment_config {
      enable_private_endpoint    = true
      master_ipv4_cidr_block     = "172.16.22.0/23"
      web_server_ipv4_cidr_block = "172.31.244.0/24"
      cloud_sql_ipv4_cidr_block  = "10.0.0.0/12"
    }
    web_server_network_access_control {
      allowed_ip_range {
        description = "network1"
        value       = "10.0.0.0/8"
      }
    }
    node_config {
      zone         = var.zone
      machine_type = "e2-medium"
      network      = google_compute_network.private_network.self_link
      subnetwork   = google_compute_subnetwork.poc-subnet.self_link
      ip_allocation_policy {
        use_ip_aliases = true
      }
      service_account = google_service_account.composer-cmek-servacc.email
    }
  }
}


locals {
  default_test_composer_env = "testcomposerenv"
  branch_test_composer_env  = "${local.default_test_composer_env}-${substr(random_id.id.hex, 0, 4)}"
  test_composer_env         = var.branchname != "release" ? local.branch_test_composer_env : local.default_test_composer_env
}

data "google_project" "test_composer_env" {
}

resource "google_project_service" "enable_composer_api" {
  project                    = var.project
  service                    = "composer.googleapis.com"
  disable_dependent_services = true
  provisioner "local-exec" {
    command = "sleep 60"
  }
}

resource "google_composer_environment" "test_composer_env" {
  depends_on = [google_project_service.enable_composer_api,]
  name   = local.test_composer_env
  region = var.region
  config {
    node_count = 3
    private_environment_config {
      enable_private_endpoint = false
    }
    node_config {
      zone         = var.zone
      machine_type = "e2-medium"
      network    = google_compute_network.private_network.self_link
      subnetwork = google_compute_subnetwork.poc-subnet.self_link
      ip_allocation_policy {
          use_ip_aliases = true
       }
      service_account = google_service_account.test_composer_env.name
    }
  }
}

resource "google_service_account" "test_composer_env" {
  account_id   = local.test_composer_env
  display_name = " Service Account for Composer Environment"
}

resource "google_project_iam_member" "test_composer_env" {
  role   = "roles/composer.environmentAndStorageObjectViewer"
  member = "serviceAccount:${google_service_account.test_composer_env.email}"
}
locals {
  default_test_composer_serviceaccount = "testcomposerserviceaccount"
  branch_test_composer_serviceaccount  = "${local.default_test_composer_serviceaccount}-${substr(random_id.id.hex, 0, 4)}"
  test_composer_serviceaccount         = var.branchname != "release" ? local.branch_test_composer_serviceaccount : local.default_test_composer_serviceaccount
}
data "google_project" "test_composer_serviceaccount" {
}
resource "google_project_service" "enable_composer_api" {
  project                    = var.project
  service                    = "composer.googleapis.com"
  disable_dependent_services = true
  provisioner "local-exec" {
    command = "sleep 60"
  }
}
resource "google_composer_environment" "test_composer_serviceaccount" {
  depends_on = [google_project_service.enable_composer_api,]
  name   = local.test_composer_serviceaccount
  region = var.region
  config {
    node_count = 3
    private_environment_config {
      enable_private_endpoint = true
      master_ipv4_cidr_block = "172.16.22.0/23"
      web_server_ipv4_cidr_block = "172.31.244.0/24"
      cloud_sql_ipv4_cidr_block = "10.0.0.0/12"
    }
    node_config {
      zone         = var.zone
      machine_type = "e2-medium"
      network    = google_compute_network.private_network.self_link
      subnetwork = google_compute_subnetwork.poc-subnet.self_link
      ip_allocation_policy {
          use_ip_aliases = true
       }
      service_account = google_service_account.test_composer_serviceaccount.name
    }
  }
}

resource "google_service_account" "test_composer_serviceaccount" {
  account_id   = local.test_composer_serviceaccount
  display_name = " Service Account for Composer Environment"
}

resource "google_project_iam_member" "test_composer_serviceaccount" {
  role   = "roles/composer.worker"
  member = "serviceAccount:${google_service_account.test_composer_serviceaccount.email}"
}
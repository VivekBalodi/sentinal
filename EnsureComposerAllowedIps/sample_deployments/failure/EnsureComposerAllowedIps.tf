locals {
  default_composer_allwd_ips = "composerallowdips"
  branch_composer_allwd_ips  = "${local.default_composer_allwd_ips}-${substr(random_id.id.hex, 0, 4)}"
  composer_allwd_ips         = var.branchname != "release" ? local.branch_composer_allwd_ips : local.default_composer_allwd_ips
}
data "google_project" "composer_allwd_ips" {
}
resource "google_project_service" "enable_composer_api" {
  project                    = var.project
  service                    = "composer.googleapis.com"
  disable_dependent_services = true
  provisioner "local-exec" {
    command = "sleep 60"
   }
}
resource "google_composer_environment" "composer_allwd_ips" {
  depends_on = [google_project_service.enable_composer_api,]
  provider = google-beta
  name   = local.composer_allwd_ips
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
      service_account = google_service_account.composer_allwd_ips.name
    }
  }
}

resource "google_service_account" "composer_allwd_ips" {
  account_id   = local.composer_allwd_ips
  display_name = " Service Account for Composer Environment"
}

resource "google_project_iam_member" "composer_allwd_ips" {
  role   = "roles/composer.worker"
  member = "serviceAccount:${google_service_account.composer_allwd_ips.email}"
}

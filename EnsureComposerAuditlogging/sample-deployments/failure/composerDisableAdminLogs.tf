resource "google_project_iam_audit_config" "composer-no-audit-logging" {
  project = var.project
  service = "composer.googleapis.com"
  audit_log_config {
    log_type = "DATA_READ"
    exempted_members = [
      "domain:deuba.com",
    ]
  }
}

resource "google_project_iam_audit_config" "composer-enable-audit-logging" {
  project = var.project
  service = "composer.googleapis.com"
  audit_log_config {
    log_type = "DATA_READ"
  }
  audit_log_config {
    log_type = "DATA_WRITE"
  }
  audit_log_config {
    log_type = "ADMIN_READ"
  }
}

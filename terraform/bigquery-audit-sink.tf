resource "google_bigquery_dataset" "gke_security_dataset" {
  dataset_id                  = "gke_security_audit_logs"
  friendly_name               = "GKE Security Audit Log Dataset"
  description                 = "Aggregated dataset for GKE security compliance auditing"
  location                    = var.region
  project                     = var.project_id
  default_table_expiration_ms = 7776000000 # 90 days retention policy
}

resource "google_logging_project_sink" "bigquery_security_sink" {
  name        = "gke-security-bigquery-sink"
  project     = var.project_id
  destination = "bigquery.googleapis.com/projects/${var.project_id}/datasets/${google_bigquery_dataset.gke_security_dataset.dataset_id}"
  filter      = <<EOT
    resource.type="gke_cluster" OR
    logName:"cloudaudit.googleapis.com" OR
    (resource.type="k8s_node" AND logName:"logs/dataplane-v2.drops")
  EOT
  unique_writer_identity = true
}

resource "google_project_iam_member" "bigquery_sink_writer" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = google_logging_project_sink.bigquery_security_sink.writer_identity
}

# created by @jsaccomani

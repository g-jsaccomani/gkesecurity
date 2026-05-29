# Pub/Sub Ingestion Topic for Cortex XSIAM
resource "google_pubsub_topic" "xsiam_logs_topic" {
  name    = "xsiam-audit-logs-topic"
  project = var.project_id
}

# Aggregated Folder-Level Logging Sink routing to Pub/Sub
resource "google_logging_folder_sink" "aggregated_cortex_sink" {
  name             = "xsiam-folder-aggregated-sink"
  folder           = var.folder_id
  destination      = "pubsub.googleapis.com/${google_pubsub_topic.xsiam_logs_topic.id}"
  include_children = true

  # Audit Filter targeting GKE Audit and eBPF Dataplane drops
  filter = <<EOT
    resource.type="gke_cluster" OR
    logName:"cloudaudit.googleapis.com" OR
    (resource.type="k8s_node" AND logName:"logs/dataplane-v2.drops")
  EOT
}

# Log Router Pub/Sub Permissions
resource "google_pubsub_topic_iam_member" "pubsub_publisher" {
  topic   = google_pubsub_topic.xsiam_logs_topic.name
  role    = "roles/pubsub.publisher"
  member  = google_logging_folder_sink.aggregated_cortex_sink.writer_identity
  project = var.project_id
}
# Org Policy: Disallow the creation of static Service Account JSON keys
resource "google_project_organization_policy" "block_service_account_keys" {
  project    = var.project_id
  constraint = "constraints/iam.disableServiceAccountKeyCreation"

  boolean_policy {
    enforced = true
  }
}

# Org Policy: Disable Google Cloud Shell in the migration project perimeter
resource "google_project_organization_policy" "disable_cloud_shell" {
  project    = var.project_id
  constraint = "constraints/compute.disableCloudShell"

  boolean_policy {
    enforced = true
  }
}
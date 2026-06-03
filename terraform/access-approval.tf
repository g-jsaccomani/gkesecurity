resource "google_access_approval_project_settings" "project_access_approval" {
  project_id          = var.project_id
  notification_emails = ["soc-alerts@enterprise-platform.com"]

  enrolled_services {
    name             = "all"
    enrollment_level = "BLOCK_ALL"
  }
}

resource "google_essential_contacts_contact" "security_contact" {
  parent              = "projects/${var.project_id}"
  email               = "soc-alerts@enterprise-platform.com"
  language_tag        = "en"
  notification_category_subscriptions = ["SECURITY", "TECHNICAL"]
}

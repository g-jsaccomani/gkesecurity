# HSM-Backed Keyring for GKE CMEK Encryption
resource "google_kms_key_ring" "hsm_keyring" {
  name     = "hsm-keyring"
  location = var.region
  project  = var.project_id
}

# etcd database encryption key
resource "google_kms_crypto_key" "etcd_key" {
  name            = "etcd-encryption-key"
  key_ring        = google_kms_key_ring.hsm_keyring.id
  rotation_period = "7776000s" # Enforce 90-day automatic rotation

  version_template {
    algorithm        = "GOOGLE_SYMMETRIC_ENCRYPTION"
    protection_level = "HSM" # Hardware-enforced encryption
  }
}

# Artifact Registry secure storage key
resource "google_kms_crypto_key" "registry_key" {
  name            = "registry-encryption-key"
  key_ring        = google_kms_key_ring.hsm_keyring.id
  rotation_period = "7776000s"

  version_template {
    algorithm        = "GOOGLE_SYMMETRIC_ENCRYPTION"
    protection_level = "HSM"
  }
}
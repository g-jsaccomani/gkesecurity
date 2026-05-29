# Hardened GKE Standard Cluster
resource "google_container_cluster" "hardened_cluster" {
  name     = "hardened-gke-cluster"
  location = "us-central1-a"
  project  = var.project_id

  # Remove the default node pool to ensure secure-by-default initialization
  remove_default_node_pool = true
  initial_node_count       = 1

  # Network & VPC Settings
  network    = var.vpc_id
  subnetwork = var.subnet_id

  # GKE Dataplane V2 configuration (eBPF-powered Cilium)
  datapath_provider = "ADVANCED_DATAPATH"

  # Enforce Private API Endpoint Isolation
  enable_private_nodes    = true
  enable_private_endpoint = true

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = true
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  # Enforce Master Authorized Networks (MAN) Firewall
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "10.0.1.0/24"
      display_name = "corp-bastion-subnet"
    }
  }

  # Enforce OIDC Workload Identity Federation
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Deploy-time security checks via Binary Authorization
  enable_binary_authorization = true

  # GKE Security Posture Dashboard (Enterprise Package)
  security_posture_config {
    mode               = "ENTERPRISE"
    vulnerability_mode = "ENTERPRISE"
  }

  # Automated GKE Lifecycle Release Channel
  release_channel {
    channel = "REGULAR"
  }

  ip_allocation_policy {
    use_ip_aliases = true
  }

  lifecycle {
    ignore_changes = [
      node_config,
    ]
  }
}

# Dedicated Custom Least-Privilege GKE Node Service Account
resource "google_service_account" "gke_node_sa" {
  account_id   = "gke-node-sa"
  display_name = "Hardened GKE Node Service Account"
  project      = var.project_id
}

# Immutable GKE Node Pool on Container-Optimized OS
resource "google_container_node_pool" "primary_hardened_nodes" {
  name       = "primary-hardened-nodes"
  cluster    = google_container_cluster.hardened_cluster.id
  node_count = 3
  project    = var.project_id

  node_config {
    image_type   = "COS_CONTAINERD" # Mandate COS runtime
    machine_type = "e2-standard-4"

    # Enforce Shielded Nodes (UEFI Secure Boot + vTPM)
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    # Block legacy endpoints to prevent SSRF credential access
    metadata = {
      disable-legacy-endpoints = "true"
    }

    service_account = google_service_account.gke_node_sa.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/devstorage.read_only"
    ]
  }

  management {
    auto_upgrade = true
    auto_repair  = true
  }
}
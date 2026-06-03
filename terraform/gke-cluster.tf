resource "google_container_cluster" "hardened_cluster" {
  name     = "hardened-gke-cluster"
  location = "us-central1-a"
  project  = var.project_id

  # Remove default pool for secure bootstrapping
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = var.vpc_id
  subnetwork = var.subnet_id

  # GKE Dataplane V2 (eBPF / Cilium)
  datapath_provider = "ADVANCED_DATAPATH"

  # Enforce private control plane connectivity
  enable_private_nodes    = true
  enable_private_endpoint = true

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = true
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "10.0.1.0/24"
      display_name = "corp-bastion-subnet"
    }
  }

  # Workload Identity Federation
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  enable_binary_authorization = true

  security_posture_config {
    mode               = "ENTERPRISE"
    vulnerability_mode = "ENTERPRISE"
  }

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

resource "google_service_account" "gke_node_sa" {
  account_id   = "gke-node-sa"
  display_name = "Hardened GKE Node Service Account"
  project      = var.project_id
}

resource "google_container_node_pool" "primary_hardened_nodes" {
  name       = "primary-hardened-nodes"
  cluster    = google_container_cluster.hardened_cluster.id
  node_count = 3
  project    = var.project_id

  node_config {
    image_type   = "COS_CONTAINERD"
    machine_type = "e2-standard-4"

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

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

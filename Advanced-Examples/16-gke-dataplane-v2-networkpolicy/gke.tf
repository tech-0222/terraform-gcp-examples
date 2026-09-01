# GKE Standard: private endpoint + private nodes. The control plane is
# reachable only from the bastion subnet (master_authorized_networks below).

# Dedicated node Service Account instead of the Compute Engine default SA.
resource "google_service_account" "gke_node" {
  account_id   = "${var.cluster_name}-node"
  display_name = "GKE node pool (${var.cluster_name})"
}

resource "google_project_iam_member" "gke_node_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_node.email}"
}

resource "google_project_iam_member" "gke_node_monitoring_metric" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_node.email}"
}

resource "google_project_iam_member" "gke_node_monitoring_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.gke_node.email}"
}

# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.zone

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.gke.name

  remove_default_node_pool = true
  initial_node_count       = 1

  deletion_protection = false

  # GKE Dataplane V2 (Cilium/eBPF-based), replacing the default
  # iptables-based kube-proxy datapath. NetworkPolicy enforcement is
  # built into Dataplane V2 -- do NOT also set a network_policy block
  # (the older Calico-based addon). Enabling both fails apply with
  # "Enabling NetworkPolicy for clusters with
  # DatapathProvider=ADVANCED_DATAPATH is not allowed."
  datapath_provider = "ADVANCED_DATAPATH"

  release_channel {
    channel = "REGULAR"
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  # Both the control plane endpoint and the nodes are private. There is no
  # path to the API server except through master_authorized_networks.
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = true
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  # Private endpoint traffic is evaluated by source (private) IP, so this
  # is the bastion subnet's range, not a public IP.
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = var.bastion_subnet_cidr
      display_name = "bastion-subnet"
    }
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  resource_labels = {
    env        = "test"
    system     = "tf-examples"
    component  = "gke"
    managed_by = "terraform"
    example    = "16-gke-dataplane-v2-networkpolicy"
  }

  depends_on = [google_compute_subnetwork.gke]
}

# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_node_pool
resource "google_container_node_pool" "primary" {
  name     = "${var.cluster_name}-np"
  location = var.zone
  cluster  = google_container_cluster.primary.name

  node_count = 1

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type    = var.node_machine_type
    disk_size_gb    = 30
    disk_type       = "pd-standard"
    service_account = google_service_account.gke_node.email
    spot            = var.use_spot

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    # Required for Workload Identity: lets Pods fetch tokens through the
    # GKE metadata server instead of the node's own credentials.
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    labels = {
      component  = "gke"
      managed_by = "terraform"
      example    = "16-gke-dataplane-v2-networkpolicy"
    }

    tags = ["gke-${var.cluster_name}"]
  }

  depends_on = [
    google_project_iam_member.gke_node_logging,
    google_project_iam_member.gke_node_monitoring_metric,
    google_project_iam_member.gke_node_monitoring_viewer,
  ]
}

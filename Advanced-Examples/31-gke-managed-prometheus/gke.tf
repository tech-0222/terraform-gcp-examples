resource "google_service_account" "node" {
  account_id   = "${var.cluster_name}-node"
  display_name = "GKE node (${var.cluster_name})"
}

resource "google_project_iam_member" "node" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.node.email}"
}

# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.zone

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.gke.name

  remove_default_node_pool = true
  initial_node_count       = 1
  deletion_protection      = false

  release_channel {
    channel = "REGULAR"
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  # ノードは外部 IP なし。コントロールプレーンは公開エンドポイントのまま
  # 許可 CIDR で絞る。踏み台を立てないのは、主題が GMP の構成比較だから。
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.31.0/28"
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = var.authorized_ipv4_cidr
      display_name = "operator"
    }
  }

  # Google Cloud Managed Service for Prometheus（GMP）の Managed Collection を使う。
  # GKE Standard 1.27 以降では既定で有効だが、ここでは明示する。
  # Ref: https://cloud.google.com/stackdriver/docs/managed-prometheus/setup-managed
  #
  # POD は managed kube-state-metrics パッケージ（Standard は 1.29.2-gke.2000 以降で
  # 既定有効）。自前で入れる kube-state-metrics と重複・不正確なメトリクスが出ないかを
  # 本記事で比較する。
  # Ref: https://cloud.google.com/kubernetes-engine/docs/how-to/kube-state-metrics
  monitoring_config {
    enable_components = [
      "SYSTEM_COMPONENTS",
      "POD",
    ]

    managed_prometheus {
      enabled = true
    }
  }

  resource_labels = {
    env        = "test"
    system     = "tf-examples"
    component  = "gke"
    managed_by = "terraform"
    example    = "31-gke-managed-prometheus"
  }

  depends_on = [google_compute_subnetwork.gke]
}

resource "google_container_node_pool" "primary" {
  name       = "${var.cluster_name}-np"
  location   = var.zone
  cluster    = google_container_cluster.primary.name
  node_count = var.node_count

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type    = var.node_machine_type
    disk_size_gb    = 30
    disk_type       = "pd-balanced"
    service_account = google_service_account.node.email
    spot            = var.use_spot

    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]

    labels = {
      component  = "gke"
      managed_by = "terraform"
      example    = "31-gke-managed-prometheus"
    }
  }

  depends_on = [google_project_iam_member.node]
}

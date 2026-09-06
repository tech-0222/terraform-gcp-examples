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
  # 許可 CIDR で絞る。踏み台を立てないのは、退避の観測が主題だから。
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.28.0/28"
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = var.authorized_ipv4_cidr
      display_name = "operator"
    }
  }

  # 退避のイベントが Cloud Logging に出るかを見るため、WORKLOADS も入れる。
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  # Google Cloud Managed Service for Prometheus（GMP）を使う。
  # 自前で kube-prometheus-stack を立てる代わりに、GKE の managed collection に
  # 集めさせて Cloud Monitoring から PromQL で引く。
  #
  # POD は kube-state-metrics 由来のメトリクス（kube_pod_status_reason など）。
  # KUBELET / CADVISOR は GKE 1.29.3-gke.1093000 以降でのみ指定できる。
  # Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster
  monitoring_config {
    enable_components = [
      "SYSTEM_COMPONENTS",
      "POD",
      "KUBELET",
      "CADVISOR",
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
    example    = "28-gke-pod-eviction"
  }

  depends_on = [google_compute_subnetwork.gke]
}

# 退避を起こしたいので、ノードは1台・小さめにする。
# 自動修復と自動アップグレードは、退避の観測中にノードが入れ替わると
# 邪魔になるため切る。
resource "google_container_node_pool" "primary" {
  name       = "${var.cluster_name}-np"
  location   = var.zone
  cluster    = google_container_cluster.primary.name
  node_count = var.node_count

  management {
    auto_repair  = false
    auto_upgrade = false
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
      example    = "28-gke-pod-eviction"
    }
  }

  depends_on = [google_project_iam_member.node]
}

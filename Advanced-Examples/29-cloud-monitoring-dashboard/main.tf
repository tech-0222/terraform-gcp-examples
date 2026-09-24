# ダッシュボードに載せるデータの発生源を3つ用意する。
# GCE（CPU）、GKE（メモリ・再起動）、Cloud Run（リクエスト・5xx・レイテンシ）。
# どれも environment ラベルを持たせ、ダッシュボードの pinned filter で絞れるかを見る。

locals {
  common_labels = {
    environment = var.environment
    managed_by  = "terraform"
    example     = "29-cloud-monitoring-dashboard"
  }
}

# ---------------------------------------------------------------------------
# GCE: CPU 使用率の発生源。外部 IP なし、Ops Agent なし。
# 起動スクリプトで5分ごとに60秒だけ CPU を回し、グラフに山を作る。
# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance
# ---------------------------------------------------------------------------
resource "google_compute_instance" "web" {
  name         = var.vm_name
  zone         = var.zone
  machine_type = var.vm_machine_type
  labels       = local.common_labels

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.main.id
  }

  scheduling {
    provisioning_model          = "SPOT"
    preemptible                 = true
    automatic_restart           = false
    instance_termination_action = "STOP"
  }

  shielded_instance_config {
    enable_secure_boot = true
  }

  metadata = {
    enable-oslogin = "TRUE"
    startup-script = <<-EOT
      #!/bin/bash
      nohup bash -c 'while true; do timeout 60 sha256sum /dev/zero; sleep 240; done' >/dev/null 2>&1 &
    EOT
  }
}

# ---------------------------------------------------------------------------
# GKE: ゾーンクラスタ、Spot ノード1台。
# ---------------------------------------------------------------------------
resource "google_service_account" "node" {
  account_id   = "${var.cluster_name}-node"
  display_name = "GKE node (${var.cluster_name})"
}

resource "google_project_iam_member" "node" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/artifactregistry.reader",
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
  subnetwork = google_compute_subnetwork.main.name

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

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.29.0/28"
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = var.authorized_ipv4_cidr
      display_name = "operator"
    }
  }

  # ダッシュボードの Logs パネルでコンテナのログを見るため WORKLOADS を入れる。
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
  }

  resource_labels = local.common_labels

  depends_on = [google_compute_subnetwork.main]
}

resource "google_container_node_pool" "primary" {
  name       = "${var.cluster_name}-np"
  location   = var.zone
  cluster    = google_container_cluster.primary.name
  node_count = 1

  node_config {
    machine_type    = var.node_machine_type
    disk_size_gb    = 30
    disk_type       = "pd-balanced"
    service_account = google_service_account.node.email
    spot            = true
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    resource_labels = local.common_labels
  }

  depends_on = [google_project_iam_member.node]
}

# ---------------------------------------------------------------------------
# Cloud Run: 5xx を任意に返せる httpbin。/status/500 で 500 を返す。
# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/cloud_run_v2_service
# ---------------------------------------------------------------------------
resource "google_cloud_run_v2_service" "api" {
  name                = var.run_service_name
  location            = var.region
  deletion_protection = false
  ingress             = "INGRESS_TRAFFIC_ALL"
  labels              = local.common_labels

  template {
    scaling {
      max_instance_count = 2
    }

    containers {
      image = var.run_image

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }
    }
  }

  depends_on = [google_project_service.required]
}

# 負荷をかけるのは手元の curl。認証を挟まないため allUsers に invoker を付ける。
# 検証が終わったら destroy する前提の設定。
resource "google_cloud_run_v2_service_iam_member" "public" {
  name     = google_cloud_run_v2_service.api.name
  location = google_cloud_run_v2_service.api.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# バックエンドは VM 1台。リージョン ALB とグローバル ALB の両方から、
# 同じゾーン NEG を通して使う。証明書の検証が主題なので、バックエンドは
# 応答があれば足りる。

data "google_compute_image" "debian" {
  family  = "debian-12"
  project = "debian-cloud"
}

resource "google_service_account" "vm" {
  account_id   = "tf-adv-cm27-vm"
  display_name = "Backend VM (27-regional-alb-certificate-manager)"
}

resource "google_compute_instance" "backend" {
  name         = "tf-adv-cm27-be"
  zone         = var.zone
  machine_type = var.machine_type
  tags         = ["lb-backend", "iap-ssh"]

  boot_disk {
    initialize_params {
      image = data.google_compute_image.debian.self_link
      size  = 10
      type  = "pd-balanced"
    }
  }

  # 外部 IP は付けない。受信は必ず LB を通る。
  network_interface {
    subnetwork = google_compute_subnetwork.workload.id
  }

  service_account {
    email  = google_service_account.vm.email
    scopes = ["cloud-platform"]
  }

  # どちらの LB から来たか分かるように、ホスト名を返す。
  metadata_startup_script = <<-EOT
    #!/bin/bash
    set -eux
    apt-get update
    apt-get install -y nginx
    cat > /var/www/html/index.html <<'HTML'
    27-regional-alb-certificate-manager backend
    HTML
    systemctl enable --now nginx
  EOT

  labels = {
    env        = "test"
    system     = "tf-examples"
    component  = "alb-backend"
    managed_by = "terraform"
    example    = "27-regional-alb-certificate-manager"
  }

  depends_on = [google_compute_router_nat.nat]
}

resource "google_compute_network_endpoint_group" "backend" {
  name         = "tf-adv-cm27-neg"
  zone         = var.zone
  network      = google_compute_network.vpc.id
  subnetwork   = google_compute_subnetwork.workload.id
  default_port = 80
}

resource "google_compute_network_endpoint" "backend" {
  network_endpoint_group = google_compute_network_endpoint_group.backend.name
  zone                   = var.zone

  instance   = google_compute_instance.backend.name
  ip_address = google_compute_instance.backend.network_interface[0].network_ip
  port       = 80
}

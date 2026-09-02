# Destination VM (Project B): runs nginx, reachable only from the GKE node
# subnet's CIDR (see google_compute_firewall.b_allow_http_from_a_nodes).
# IAP SSH access lets us tcpdump the VM's own interface during verification.

resource "google_project_iam_member" "b_iap_tunnel" {
  provider = google.b

  project = var.target_project_id
  role    = "roles/iap.tunnelResourceAccessor"
  member  = var.iap_member
}

resource "google_project_iam_member" "b_compute_viewer" {
  provider = google.b

  project = var.target_project_id
  role    = "roles/compute.viewer"
  member  = var.iap_member
}

resource "google_project_iam_member" "b_os_login" {
  provider = google.b

  project = var.target_project_id
  role    = "roles/compute.osLogin"
  member  = var.iap_member
}

resource "google_compute_instance" "target_vm" {
  provider = google.b

  name         = var.target_vm_name
  zone         = var.zone
  machine_type = var.target_vm_machine_type
  tags         = ["http", "iap-ssh"]

  boot_disk {
    initialize_params {
      image = "projects/debian-cloud/global/images/family/debian-12"
      size  = 10
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.target.id
    network_ip = var.target_vm_ip
    # No external IP: reachable only via IAP TCP forwarding for SSH, and
    # from the GKE node subnet for HTTP.
  }

  scheduling {
    preemptible       = var.use_spot
    automatic_restart = !var.use_spot # required when preemptible = true
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    set -euxo pipefail
    apt-get update
    apt-get install -y nginx tcpdump
    echo "hello from target-vm" > /var/www/html/index.html
    systemctl enable --now nginx
  EOT

  labels = {
    env        = "test"
    system     = "tf-examples"
    component  = "target-vm"
    managed_by = "terraform"
    example    = "17-gke-routes-based-ip-masq"
  }

  depends_on = [
    google_compute_firewall.b_allow_http_from_a_nodes,
    google_compute_firewall.b_allow_iap_ssh,
  ]
}

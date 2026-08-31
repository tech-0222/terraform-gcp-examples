# Bastion VM: the only path to the private GKE control plane.
# No external IP; outbound access goes through Cloud NAT (network.tf).

# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_service_account
resource "google_service_account" "bastion" {
  account_id   = "${var.bastion_instance_name}-sa"
  display_name = "Bastion for private GKE access"
}

# container.admin (not container.clusterAdmin, which excludes nodes.list)
# so `kubectl get nodes` works from the bastion using this SA.
resource "google_project_iam_member" "bastion_gke" {
  project = var.project_id
  role    = "roles/container.admin"
  member  = "serviceAccount:${google_service_account.bastion.email}"
}

# enable-oslogin = TRUE below requires these three for IAP SSH to succeed.
resource "google_project_iam_member" "iap_tunnel" {
  project = var.project_id
  role    = "roles/iap.tunnelResourceAccessor"
  member  = var.iap_member
}

resource "google_project_iam_member" "compute_viewer" {
  project = var.project_id
  role    = "roles/compute.viewer"
  member  = var.iap_member
}

resource "google_project_iam_member" "os_login" {
  project = var.project_id
  role    = "roles/compute.osLogin"
  member  = var.iap_member
}

# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance
resource "google_compute_instance" "bastion" {
  name         = var.bastion_instance_name
  machine_type = var.bastion_machine_type
  zone         = var.zone
  tags         = ["bastion"]

  boot_disk {
    initialize_params {
      image = "projects/debian-cloud/global/images/family/debian-12"
      size  = 20
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.bastion.id
    # No external IP: reachable only via IAP TCP forwarding.
  }

  service_account {
    email  = google_service_account.bastion.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  # kubectl and the GKE auth plugin are not preinstalled on Debian.
  # Package name is google-cloud-cli-gke-gcloud-auth-plugin, not
  # google-cloud-sdk-gke-gcloud-auth-plugin (renamed upstream; the old name
  # has no installation candidate on this image's apt repo).
  metadata_startup_script = <<-EOT
    #!/bin/bash
    set -euxo pipefail
    apt-get update
    apt-get install -y kubectl google-cloud-cli-gke-gcloud-auth-plugin
  EOT

  labels = {
    env        = "test"
    system     = "tf-examples"
    component  = "gke-bastion"
    managed_by = "terraform"
    example    = "14-gke-bastion-ilb-multi-neg"
  }

  depends_on = [
    google_compute_firewall.allow_iap_ssh_bastion,
    google_project_iam_member.bastion_gke,
  ]
}

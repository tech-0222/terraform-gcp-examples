# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_service
resource "google_project_service" "compute" {
  project = var.project_id
  service = "compute.googleapis.com"

  disable_on_destroy = false
}

data "google_compute_image" "debian" {
  family  = "debian-12"
  project = "debian-cloud"
}

# Spot VM (may be preempted). Suitable for disposable learning workloads.
# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance
resource "google_compute_instance" "vm" {
  name         = var.instance_name
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["iap-ssh"]

  boot_disk {
    initialize_params {
      image = data.google_compute_image.debian.self_link
      size  = 20
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.primary.id
    # No external IP: access via IAP TCP forwarding.
  }

  scheduling {
    provisioning_model = "SPOT"
    preemptible        = true
    automatic_restart  = false
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  labels = {
    env        = "test"
    system     = "tf-examples"
    component  = "compute"
    managed_by = "terraform"
    example    = "04-compute-engine"
  }

  # Spot may be reclaimed at any time; this sample is for short-lived verification only.
  allow_stopping_for_update = true
}

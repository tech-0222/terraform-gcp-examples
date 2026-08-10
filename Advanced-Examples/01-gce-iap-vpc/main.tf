# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_service
resource "google_project_service" "required" {
  for_each = toset([
    "compute.googleapis.com",
    "iap.googleapis.com",
    "iam.googleapis.com",
    "oslogin.googleapis.com",
  ])

  project = var.project_id
  service = each.value

  disable_on_destroy = false
}

# Dedicated runtime identity for the VM (no SA keys).
# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_service_account
resource "google_service_account" "vm" {
  account_id   = "tf-adv-gce-iap-vm"
  display_name = "Advanced example VM (IAP SSH)"
  description  = "Runtime SA for Advanced-Examples/01-gce-iap-vpc."

  depends_on = [google_project_service.required]
}

data "google_compute_image" "debian" {
  family  = "debian-12"
  project = "debian-cloud"
}

# Spot VM without external IP. Access via IAP TCP forwarding + OS Login.
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
    # No external IP: SSH only through IAP.
  }

  service_account {
    email  = google_service_account.vm.email
    scopes = ["cloud-platform"]
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
    example    = "01-gce-iap-vpc"
  }

  # Spot may be reclaimed at any time; short-lived verification only.
  allow_stopping_for_update = true

  depends_on = [
    google_compute_firewall.allow_iap_ssh,
    google_project_iam_member.iap_tunnel,
    google_project_iam_member.os_login,
  ]
}

# Project-level IAP tunnel user (required for gcloud --tunnel-through-iap).
# Ref: https://cloud.google.com/iap/docs/using-tcp-forwarding#grant-permission
resource "google_project_iam_member" "iap_tunnel" {
  project = var.project_id
  role    = "roles/iap.tunnelResourceAccessor"
  member  = var.iap_member

  depends_on = [google_project_service.required]
}

# OS Login for the same principal (SSH identity without managing SSH keys in metadata).
# Ref: https://cloud.google.com/compute/docs/oslogin/set-up-oslogin
resource "google_project_iam_member" "os_login" {
  project = var.project_id
  role    = "roles/compute.osLogin"
  member  = var.iap_member

  depends_on = [google_project_service.required]
}

# Instance-level IAP tunnel binding (defense in depth / explicit resource ACL).
# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/iap_tunnel_instance_iam
resource "google_iap_tunnel_instance_iam_member" "ssh" {
  project  = var.project_id
  zone     = google_compute_instance.vm.zone
  instance = google_compute_instance.vm.name
  role     = "roles/iap.tunnelResourceAccessor"
  member   = var.iap_member
}

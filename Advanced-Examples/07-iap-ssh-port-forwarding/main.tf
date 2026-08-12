resource "google_project_service" "required" {
  for_each = toset([
    "compute.googleapis.com",
    "iap.googleapis.com",
    "iam.googleapis.com",
    "oslogin.googleapis.com",
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_service_account" "vm" {
  account_id   = "tf-adv-iap-forward-vm"
  display_name = "Advanced IAP SSH port forwarding VM"
  description  = "Runtime identity for Advanced-Examples/07-iap-ssh-port-forwarding."

  depends_on = [google_project_service.required]
}

data "google_compute_image" "debian" {
  family  = "debian-12"
  project = "debian-cloud"
}

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
    # No access_config: the VM has no external IP.
  }

  service_account {
    email  = google_service_account.vm.email
    scopes = ["https://www.googleapis.com/auth/logging.write"]
  }

  scheduling {
    provisioning_model = "SPOT"
    preemptible        = true
    automatic_restart  = false
  }

  metadata = {
    enable-oslogin = "TRUE"
    startup-script = file("${path.module}/startup.sh")
  }

  labels = {
    env        = "test"
    system     = "tf-examples"
    component  = "compute"
    managed_by = "terraform"
    example    = "07-iap-ssh-port-forwarding"
  }

  allow_stopping_for_update = true

  depends_on = [
    google_compute_router_nat.nat,
    google_compute_firewall.allow_iap_ssh,
    google_project_iam_member.iap_tunnel,
    google_project_iam_member.os_login,
  ]
}

resource "google_project_iam_member" "iap_tunnel" {
  project = var.project_id
  role    = "roles/iap.tunnelResourceAccessor"
  member  = var.iap_member

  depends_on = [google_project_service.required]
}

resource "google_project_iam_member" "os_login" {
  project = var.project_id
  role    = "roles/compute.osLogin"
  member  = var.iap_member

  depends_on = [google_project_service.required]
}

resource "google_iap_tunnel_instance_iam_member" "ssh" {
  project  = var.project_id
  zone     = google_compute_instance.vm.zone
  instance = google_compute_instance.vm.name
  role     = "roles/iap.tunnelResourceAccessor"
  member   = var.iap_member
}

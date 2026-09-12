locals {
  record_fqdn = "${var.record_name}.${var.dns_name}"
}

# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_service
resource "google_project_service" "dns" {
  project = var.project_id
  service = "dns.googleapis.com"

  disable_on_destroy = false
}

# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_managed_zone
resource "google_dns_managed_zone" "private" {
  name        = var.managed_zone_name
  dns_name    = var.dns_name
  description = "Private DNS zone for terraform-gcp-examples"
  visibility  = "private"

  private_visibility_config {
    networks {
      network_url = google_compute_network.dns.id
    }
  }

  depends_on = [google_project_service.dns]
}

# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_record_set
resource "google_dns_record_set" "example" {
  name         = local.record_fqdn
  managed_zone = google_dns_managed_zone.private.name
  type         = "A"
  ttl          = var.record_ttl
  rrdatas      = [var.record_ip]
}

data "google_compute_image" "debian" {
  family  = "debian-12"
  project = "debian-cloud"
}

# VM in the VPC bound to the private zone: resolution is expected to succeed.
# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance
resource "google_compute_instance" "vm_in_zone" {
  name         = var.vm_in_zone_name
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
    subnetwork = google_compute_subnetwork.dns.id
    # No external IP: access via IAP TCP forwarding.
  }

  scheduling {
    provisioning_model = "SPOT"
    preemptible        = true
    automatic_restart  = false

    # 既定値だが、書かないと apply のたびに STOP -> null の差分が出る。
    instance_termination_action = "STOP"
  }

  metadata = {
    enable-oslogin = "TRUE"
  }
}

# VM in a separate VPC, not bound to the private zone: resolution is
# expected to fail (timeout / NXDOMAIN depending on the resolver).
# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance
resource "google_compute_instance" "vm_outside_zone" {
  name         = var.vm_outside_zone_name
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
    subnetwork = google_compute_subnetwork.external.id
    # No external IP: access via IAP TCP forwarding.
  }

  scheduling {
    provisioning_model = "SPOT"
    preemptible        = true
    automatic_restart  = false

    # 既定値だが、書かないと apply のたびに STOP -> null の差分が出る。
    instance_termination_action = "STOP"
  }

  metadata = {
    enable-oslogin = "TRUE"
  }
}

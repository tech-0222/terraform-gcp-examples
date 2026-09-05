# The VM. Terraform creates it; Ansible configures it.
#
# The line between the two is the subject of this example:
#   Terraform  -- the machine, its identity, its network, its firewall rules
#   Ansible    -- packages, service configuration, files on disk
#
# The handover happens through metadata_startup_script, which is the part that
# behaves in ways worth measuring: it runs on first boot only.

resource "google_service_account" "vm" {
  account_id   = "${var.instance_name}-sa"
  display_name = "GCE VM configured by Ansible"
}

# Read the playbook from GCS. objectViewer on the one bucket, not project-wide.
resource "google_storage_bucket_iam_member" "vm_read" {
  bucket = google_storage_bucket.ansible.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.vm.email}"
}

# The Ops Agent needs these to ship logs and metrics. Without logWriter,
# nothing from this VM reaches Cloud Logging at all.
resource "google_project_iam_member" "vm" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.vm.email}"
}

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

resource "google_compute_instance" "web" {
  name         = var.instance_name
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["web"]

  boot_disk {
    initialize_params {
      image = "projects/debian-cloud/global/images/family/debian-12"
      size  = 20
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.main.id
    # No external IP. Outbound via Cloud NAT, inbound via IAP.
  }

  scheduling {
    provisioning_model = var.use_spot ? "SPOT" : "STANDARD"
    preemptible        = var.use_spot
    automatic_restart  = var.use_spot ? false : true
  }

  service_account {
    email  = google_service_account.vm.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  metadata_startup_script = templatefile("${path.module}/startup.sh.tpl", {
    bucket   = google_storage_bucket.ansible.name
    playbook = "site.yml"
  })

  labels = {
    env        = "test"
    system     = "tf-examples"
    managed_by = "terraform"
    example    = "25-gce-ansible-ops-agent-nginx"
  }

  # The startup script reads the bucket, so the objects have to exist first.
  # Terraform cannot infer this: nothing in the instance definition references
  # the objects.
  depends_on = [
    google_storage_bucket_object.ansible,
    google_storage_bucket_iam_member.vm_read,
    google_project_iam_member.vm,
    google_compute_router_nat.nat,
  ]
}

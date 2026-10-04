resource "google_compute_network" "lab" {
  name                    = var.network_name
  auto_create_subnetworks = false

  depends_on = [google_project_service.this]
}

resource "google_compute_subnetwork" "lab" {
  name                     = "${var.network_name}-subnet"
  region                   = var.region
  network                  = google_compute_network.lab.id
  ip_cidr_range            = var.subnet_cidr
  private_ip_google_access = true
}

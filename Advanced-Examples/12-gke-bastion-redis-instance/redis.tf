# Memorystore for Redis (BASIC tier), reachable from Pods over the GKE VPC.
# Requires Private Service Access (PSA): a peering range plus a VPC peering
# connection to Google's service producer network.

resource "google_project_service" "redis" {
  project = var.project_id
  service = "redis.googleapis.com"

  disable_on_destroy = false
}

resource "google_project_service" "service_networking" {
  project = var.project_id
  service = "servicenetworking.googleapis.com"

  disable_on_destroy = false
}

# Reserved range for the PSA peering. Must not overlap with any subnet or
# the GKE master CIDR.
# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_address
resource "google_compute_global_address" "redis_psa_range" {
  name          = "${var.network_name}-redis-psa-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 24
  network       = google_compute_network.vpc.id

  depends_on = [google_project_service.service_networking]
}

# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_networking_connection
resource "google_service_networking_connection" "redis_psa" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.redis_psa_range.name]
}

# authorized_network makes the instance reachable from any resource inside
# that VPC -- no separate firewall rule is needed for PSA traffic.
# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/redis_instance
resource "google_redis_instance" "cache" {
  name               = "${var.cluster_name}-redis"
  region             = var.region
  tier               = "BASIC"
  memory_size_gb     = var.redis_memory_size_gb
  authorized_network = google_compute_network.vpc.id

  depends_on = [
    google_project_service.redis,
    google_service_networking_connection.redis_psa,
  ]
}

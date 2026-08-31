# Memorystore for Redis Cluster, reachable from Pods over Private Service
# Connect (PSC). Unlike Redis Instance's PSA (see
# 12-gke-bastion-redis-instance), Redis Cluster requires a dedicated PSC
# subnet and a Service Connection Policy.

resource "google_project_service" "redis" {
  project = var.project_id
  service = "redis.googleapis.com"

  disable_on_destroy = false
}

# Required to manage the Service Connection Policy below.
resource "google_project_service" "networkconnectivity" {
  project = var.project_id
  service = "networkconnectivity.googleapis.com"

  disable_on_destroy = false
}

# Required when Google Cloud provisions the producer-side Service Account
# for the Service Connection Policy.
resource "google_project_service" "serviceconsumermanagement" {
  project = var.project_id
  service = "serviceconsumermanagement.googleapis.com"

  disable_on_destroy = false
}

# PSC endpoint subnet. /29 is Google's recommended minimum. Must not
# overlap with the GKE/bastion subnets or the master CIDR.
resource "google_compute_subnetwork" "redis_psc" {
  name          = "${var.network_name}-redis-psc-subnet"
  ip_cidr_range = var.redis_psc_subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc.id
}

# Redis Cluster requires this policy before the cluster itself can be
# created; it is what makes PSC endpoints in the given subnet available to
# the "gcp-memorystore-redis" service class.
# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/network_connectivity_service_connection_policy
resource "google_network_connectivity_service_connection_policy" "redis_psc" {
  name          = "${var.network_name}-redis-psc-policy"
  location      = var.region
  service_class = "gcp-memorystore-redis"
  network       = google_compute_network.vpc.id

  psc_config {
    subnetworks = [google_compute_subnetwork.redis_psc.id]
  }

  depends_on = [
    google_project_service.networkconnectivity,
    google_project_service.serviceconsumermanagement,
  ]
}

# Smallest cluster: 1 shard, no replica, smallest node type. A learning
# sample, not a highly-available configuration.
# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/redis_cluster
resource "google_redis_cluster" "cache" {
  name   = "${var.cluster_name}-rediscl"
  region = var.region

  shard_count   = var.redis_shard_count
  replica_count = var.redis_replica_count
  node_type     = var.redis_node_type

  deletion_protection_enabled = false

  psc_configs {
    network = google_compute_network.vpc.id
  }

  transit_encryption_mode = "TRANSIT_ENCRYPTION_MODE_DISABLED"
  authorization_mode      = "AUTH_MODE_DISABLED"

  zone_distribution_config {
    mode = "MULTI_ZONE"
  }

  depends_on = [
    google_project_service.redis,
    google_network_connectivity_service_connection_policy.redis_psc,
  ]
}

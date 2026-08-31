# Internal HTTP LB (INTERNAL_MANAGED) with GKE Pods as NEG backends.
#
# Deploy order (two-phase apply -- the NEGs referenced below do not exist
# until a Kubernetes Service with a cloud.google.com/neg annotation has
# been applied to the already-running cluster):
#   1. terraform apply                      (enable_ilb=false, the default)
#   2. kubectl apply -f k8s/ilb-app-a.yaml -f k8s/ilb-app-b.yaml -f k8s/ilb-app-c.yaml
#      wait 1-2 minutes for GKE to create the neg-app-a/b/c NEGs
#   3. terraform apply -var="enable_ilb=true"
#
# All resources below are gated on enable_ilb so the first apply (which
# creates the cluster the NEGs depend on) does not try to reference NEGs
# that do not exist yet.

resource "google_compute_subnetwork" "proxy_only" {
  count = var.enable_ilb ? 1 : 0

  name          = "${var.network_name}-proxy-only"
  region        = var.region
  network       = google_compute_network.vpc.id
  ip_cidr_range = var.ilb_proxy_subnet_cidr
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
}

# Google's health check probers.
resource "google_compute_firewall" "allow_ilb_health_check" {
  count = var.enable_ilb ? 1 : 0

  name    = "${var.network_name}-allow-ilb-health-check"
  network = google_compute_network.vpc.name

  direction     = "INGRESS"
  target_tags   = ["gke-${var.cluster_name}"]
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }
}

# The Envoy-based proxies that sit between the forwarding rule and the
# backends (required for INTERNAL_MANAGED, unlike the older INTERNAL
# passthrough scheme).
resource "google_compute_firewall" "allow_ilb_proxies" {
  count = var.enable_ilb ? 1 : 0

  name    = "${var.network_name}-allow-ilb-proxies"
  network = google_compute_network.vpc.name

  direction     = "INGRESS"
  target_tags   = ["gke-${var.cluster_name}"]
  source_ranges = [var.ilb_proxy_subnet_cidr]

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }
}

resource "google_compute_region_health_check" "hc_app_a" {
  count   = var.enable_ilb ? 1 : 0
  name    = "${var.cluster_name}-hc-app-a"
  region  = var.region
  project = var.project_id

  http_health_check {
    port         = 8080
    request_path = "/"
  }
}

resource "google_compute_region_health_check" "hc_app_b" {
  count   = var.enable_ilb ? 1 : 0
  name    = "${var.cluster_name}-hc-app-b"
  region  = var.region
  project = var.project_id

  http_health_check {
    port         = 8080
    request_path = "/"
  }
}

resource "google_compute_region_health_check" "hc_app_c" {
  count   = var.enable_ilb ? 1 : 0
  name    = "${var.cluster_name}-hc-app-c"
  region  = var.region
  project = var.project_id

  http_health_check {
    port         = 8080
    request_path = "/"
  }
}

# Backend services reference NEGs by name (neg-app-a/b/c), one per zone in
# var.gke_zones. The NEG is not a Terraform-managed resource -- GKE creates
# it from the Service's cloud.google.com/neg annotation -- so this is a
# plain URL string, not a resource reference. Terraform cannot verify the
# NEG exists at plan time; if it does not, apply fails with a 404 from the
# API, not a Terraform-level error.
resource "google_compute_region_backend_service" "bs_app_a" {
  count                 = var.enable_ilb ? 1 : 0
  name                  = "${var.cluster_name}-bs-app-a"
  region                = var.region
  project               = var.project_id
  load_balancing_scheme = "INTERNAL_MANAGED"
  protocol              = "HTTP"
  health_checks         = [google_compute_region_health_check.hc_app_a[0].id]

  dynamic "backend" {
    for_each = toset(var.gke_zones)
    content {
      group                 = "https://www.googleapis.com/compute/v1/projects/${var.project_id}/zones/${backend.key}/networkEndpointGroups/neg-app-a"
      balancing_mode        = "RATE"
      max_rate_per_endpoint = 100
      capacity_scaler       = 1.0
    }
  }
}

resource "google_compute_region_backend_service" "bs_app_b" {
  count                 = var.enable_ilb ? 1 : 0
  name                  = "${var.cluster_name}-bs-app-b"
  region                = var.region
  project               = var.project_id
  load_balancing_scheme = "INTERNAL_MANAGED"
  protocol              = "HTTP"
  health_checks         = [google_compute_region_health_check.hc_app_b[0].id]

  dynamic "backend" {
    for_each = toset(var.gke_zones)
    content {
      group                 = "https://www.googleapis.com/compute/v1/projects/${var.project_id}/zones/${backend.key}/networkEndpointGroups/neg-app-b"
      balancing_mode        = "RATE"
      max_rate_per_endpoint = 100
      capacity_scaler       = 1.0
    }
  }
}

resource "google_compute_region_backend_service" "bs_app_c" {
  count                 = var.enable_ilb ? 1 : 0
  name                  = "${var.cluster_name}-bs-app-c"
  region                = var.region
  project               = var.project_id
  load_balancing_scheme = "INTERNAL_MANAGED"
  protocol              = "HTTP"
  health_checks         = [google_compute_region_health_check.hc_app_c[0].id]

  dynamic "backend" {
    for_each = toset(var.gke_zones)
    content {
      group                 = "https://www.googleapis.com/compute/v1/projects/${var.project_id}/zones/${backend.key}/networkEndpointGroups/neg-app-c"
      balancing_mode        = "RATE"
      max_rate_per_endpoint = 100
      capacity_scaler       = 1.0
    }
  }
}

# One VIP shared across three forwarding rules (:81/:82/:83), each routed
# to a different backend service by its own URL map + target HTTP proxy.
resource "google_compute_region_url_map" "urlmap_81" {
  count           = var.enable_ilb ? 1 : 0
  name            = "${var.cluster_name}-um-ilb-81"
  region          = var.region
  project         = var.project_id
  default_service = google_compute_region_backend_service.bs_app_a[0].id
}

resource "google_compute_region_url_map" "urlmap_82" {
  count           = var.enable_ilb ? 1 : 0
  name            = "${var.cluster_name}-um-ilb-82"
  region          = var.region
  project         = var.project_id
  default_service = google_compute_region_backend_service.bs_app_b[0].id
}

resource "google_compute_region_url_map" "urlmap_83" {
  count           = var.enable_ilb ? 1 : 0
  name            = "${var.cluster_name}-um-ilb-83"
  region          = var.region
  project         = var.project_id
  default_service = google_compute_region_backend_service.bs_app_c[0].id
}

resource "google_compute_region_target_http_proxy" "http_proxy_81" {
  count   = var.enable_ilb ? 1 : 0
  name    = "${var.cluster_name}-thp-ilb-81"
  region  = var.region
  project = var.project_id
  url_map = google_compute_region_url_map.urlmap_81[0].id
}

resource "google_compute_region_target_http_proxy" "http_proxy_82" {
  count   = var.enable_ilb ? 1 : 0
  name    = "${var.cluster_name}-thp-ilb-82"
  region  = var.region
  project = var.project_id
  url_map = google_compute_region_url_map.urlmap_82[0].id
}

resource "google_compute_region_target_http_proxy" "http_proxy_83" {
  count   = var.enable_ilb ? 1 : 0
  name    = "${var.cluster_name}-thp-ilb-83"
  region  = var.region
  project = var.project_id
  url_map = google_compute_region_url_map.urlmap_83[0].id
}

resource "google_compute_address" "ilb_vip" {
  count        = var.enable_ilb ? 1 : 0
  name         = "${var.cluster_name}-ilb-vip"
  region       = var.region
  project      = var.project_id
  address_type = "INTERNAL"
  subnetwork   = google_compute_subnetwork.gke.id
  purpose      = "SHARED_LOADBALANCER_VIP"
  address      = var.ilb_vip_address
}

resource "google_compute_forwarding_rule" "fr_81" {
  count                 = var.enable_ilb ? 1 : 0
  name                  = "${var.cluster_name}-fr-ilb-81"
  region                = var.region
  project               = var.project_id
  load_balancing_scheme = "INTERNAL_MANAGED"
  ip_protocol           = "TCP"
  port_range            = "81"

  network      = google_compute_network.vpc.id
  subnetwork   = google_compute_subnetwork.gke.id
  ip_address   = google_compute_address.ilb_vip[0].address
  target       = google_compute_region_target_http_proxy.http_proxy_81[0].id
  network_tier = "PREMIUM"

  depends_on = [google_compute_subnetwork.proxy_only]
}

resource "google_compute_forwarding_rule" "fr_82" {
  count                 = var.enable_ilb ? 1 : 0
  name                  = "${var.cluster_name}-fr-ilb-82"
  region                = var.region
  project               = var.project_id
  load_balancing_scheme = "INTERNAL_MANAGED"
  ip_protocol           = "TCP"
  port_range            = "82"

  network      = google_compute_network.vpc.id
  subnetwork   = google_compute_subnetwork.gke.id
  ip_address   = google_compute_address.ilb_vip[0].address
  target       = google_compute_region_target_http_proxy.http_proxy_82[0].id
  network_tier = "PREMIUM"

  depends_on = [google_compute_subnetwork.proxy_only]
}

resource "google_compute_forwarding_rule" "fr_83" {
  count                 = var.enable_ilb ? 1 : 0
  name                  = "${var.cluster_name}-fr-ilb-83"
  region                = var.region
  project               = var.project_id
  load_balancing_scheme = "INTERNAL_MANAGED"
  ip_protocol           = "TCP"
  port_range            = "83"

  network      = google_compute_network.vpc.id
  subnetwork   = google_compute_subnetwork.gke.id
  ip_address   = google_compute_address.ilb_vip[0].address
  target       = google_compute_region_target_http_proxy.http_proxy_83[0].id
  network_tier = "PREMIUM"

  depends_on = [google_compute_subnetwork.proxy_only]
}

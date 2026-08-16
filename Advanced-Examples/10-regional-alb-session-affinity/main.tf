data "google_compute_image" "debian" {
  family  = "debian-12"
  project = "debian-cloud"
}

locals {
  backends = {
    a  = { name = "tf-adv-elb10-a", identity = "backend-a" }
    a2 = { name = "tf-adv-elb10-a2", identity = "backend-a2" }
  }
}

resource "google_compute_address" "be" {
  for_each     = local.backends
  name         = "${each.value.name}-ip"
  region       = var.region
  address_type = "INTERNAL"
  subnetwork   = google_compute_subnetwork.workload.id
}

resource "google_compute_instance" "be" {
  for_each     = local.backends
  name         = each.value.name
  zone         = var.zone
  machine_type = var.machine_type
  tags         = ["lb-backend", "iap-ssh"]

  boot_disk {
    initialize_params {
      image = data.google_compute_image.debian.self_link
      size  = 10
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.workload.id
    network_ip = google_compute_address.be[each.key].address
  }

  metadata = {
    startup-script = templatefile("${path.module}/startup-cookie.sh.tftpl", {
      identity = each.value.identity
    })
  }

  labels = {
    env        = "test"
    system     = "tf-examples"
    component  = "alb"
    managed_by = "terraform"
    example    = "10-regional-alb-session-affinity"
    identity   = each.value.identity
  }

  allow_stopping_for_update = true

  depends_on = [
    google_compute_router_nat.nat,
    google_compute_firewall.allow_health_check,
    google_compute_firewall.allow_proxies,
  ]
}

resource "google_compute_network_endpoint_group" "neg" {
  name                  = "tf-adv-elb10-neg"
  zone                  = var.zone
  network               = google_compute_network.vpc.id
  subnetwork            = google_compute_subnetwork.workload.id
  network_endpoint_type = "GCE_VM_IP_PORT"
  default_port          = 8080
}

resource "google_compute_network_endpoint" "ep" {
  for_each               = local.backends
  network_endpoint_group = google_compute_network_endpoint_group.neg.name
  zone                   = var.zone
  instance               = google_compute_instance.be[each.key].self_link
  ip_address             = google_compute_address.be[each.key].address
  port                   = 8080
}

resource "google_compute_region_health_check" "hc" {
  name   = "tf-adv-elb10-hc"
  region = var.region

  http_health_check {
    port         = 8080
    request_path = "/"
  }
}

# :81 — LB issues GCLB cookie.
# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_backend_service
resource "google_compute_region_backend_service" "bs_generated" {
  name                    = "tf-adv-elb10-bs-gclb"
  region                  = var.region
  load_balancing_scheme   = "EXTERNAL_MANAGED"
  protocol                = "HTTP"
  health_checks           = [google_compute_region_health_check.hc.id]
  session_affinity        = "GENERATED_COOKIE"
  affinity_cookie_ttl_sec = var.affinity_cookie_ttl_sec

  backend {
    group                 = google_compute_network_endpoint_group.neg.id
    balancing_mode        = "RATE"
    max_rate_per_endpoint = 100
    capacity_scaler       = 1.0
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }

  depends_on = [google_compute_network_endpoint.ep]
}

# :83 — app Set-Cookie: ROUTE=... plus RING_HASH consistent_hash.
resource "google_compute_region_backend_service" "bs_http_cookie" {
  name                    = "tf-adv-elb10-bs-route"
  region                  = var.region
  load_balancing_scheme   = "EXTERNAL_MANAGED"
  protocol                = "HTTP"
  health_checks           = [google_compute_region_health_check.hc.id]
  session_affinity        = "HTTP_COOKIE"
  affinity_cookie_ttl_sec = var.affinity_cookie_ttl_sec
  locality_lb_policy      = "RING_HASH"

  consistent_hash {
    http_cookie {
      name = "ROUTE"
      path = "/"
      ttl {
        seconds = var.affinity_cookie_ttl_sec
      }
    }
  }

  backend {
    group                 = google_compute_network_endpoint_group.neg.id
    balancing_mode        = "RATE"
    max_rate_per_endpoint = 100
    capacity_scaler       = 1.0
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }

  depends_on = [google_compute_network_endpoint.ep]
}

resource "google_compute_region_url_map" "urlmap_81" {
  name            = "tf-adv-elb10-um-81"
  region          = var.region
  default_service = google_compute_region_backend_service.bs_generated.id
}

resource "google_compute_region_url_map" "urlmap_83" {
  name            = "tf-adv-elb10-um-83"
  region          = var.region
  default_service = google_compute_region_backend_service.bs_http_cookie.id
}

resource "google_compute_region_target_http_proxy" "proxy_81" {
  name    = "tf-adv-elb10-tp-81"
  region  = var.region
  url_map = google_compute_region_url_map.urlmap_81.id
}

resource "google_compute_region_target_http_proxy" "proxy_83" {
  name    = "tf-adv-elb10-tp-83"
  region  = var.region
  url_map = google_compute_region_url_map.urlmap_83.id
}

resource "google_compute_address" "vip" {
  name         = "tf-adv-elb10-vip"
  region       = var.region
  address_type = "EXTERNAL"
  network_tier = "PREMIUM"
}

resource "google_compute_forwarding_rule" "fr_81" {
  name                  = "tf-adv-elb10-fr-81"
  region                = var.region
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_protocol           = "TCP"
  port_range            = "81"
  ip_address            = google_compute_address.vip.address
  target                = google_compute_region_target_http_proxy.proxy_81.id
  network_tier          = "PREMIUM"
  network               = google_compute_network.vpc.id

  depends_on = [google_compute_subnetwork.proxy_only]
}

resource "google_compute_forwarding_rule" "fr_83" {
  name                  = "tf-adv-elb10-fr-83"
  region                = var.region
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_protocol           = "TCP"
  port_range            = "83"
  ip_address            = google_compute_address.vip.address
  target                = google_compute_region_target_http_proxy.proxy_83.id
  network_tier          = "PREMIUM"
  network               = google_compute_network.vpc.id

  depends_on = [google_compute_subnetwork.proxy_only]
}

data "google_compute_image" "debian" {
  family  = "debian-12"
  project = "debian-cloud"
}

locals {
  backends = {
    a = {
      name     = "tf-adv-elb08-a"
      zone     = var.zone_a
      script   = "scripts/startup-a.sh"
      identity = "backend-a"
    }
    a2 = {
      name     = "tf-adv-elb08-a2"
      zone     = var.zone_a
      script   = "scripts/startup-a2.sh"
      identity = "backend-a2"
    }
    b = {
      name     = "tf-adv-elb08-b"
      zone     = var.zone_c
      script   = "scripts/startup-b.sh"
      identity = "backend-b"
    }
  }
}

resource "google_compute_address" "be" {
  for_each = local.backends

  name         = "${each.value.name}-ip"
  region       = var.region
  address_type = "INTERNAL"
  subnetwork   = google_compute_subnetwork.workload.id
}

# Standard (not Spot): health checks need a stable backend.
# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_instance
resource "google_compute_instance" "be" {
  for_each = local.backends

  name         = each.value.name
  zone         = each.value.zone
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
    startup-script = file("${path.module}/${each.value.script}")
  }

  labels = {
    env        = "test"
    system     = "tf-examples"
    component  = "alb"
    managed_by = "terraform"
    example    = "08-regional-external-alb-neg"
    identity   = each.value.identity
  }

  allow_stopping_for_update = true

  depends_on = [
    google_compute_router_nat.nat,
    google_compute_firewall.allow_health_check,
    google_compute_firewall.allow_proxies,
  ]
}

# Zonal NEG: GCE_VM_IP_PORT. The NEG zone must match the VM zone.
# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network_endpoint_group
resource "google_compute_network_endpoint_group" "neg_a" {
  name                  = "tf-adv-elb08-neg-a"
  zone                  = var.zone_a
  network               = google_compute_network.vpc.id
  subnetwork            = google_compute_subnetwork.workload.id
  network_endpoint_type = "GCE_VM_IP_PORT"
  default_port          = 8080
}

resource "google_compute_network_endpoint_group" "neg_b" {
  name                  = "tf-adv-elb08-neg-b"
  zone                  = var.zone_c
  network               = google_compute_network.vpc.id
  subnetwork            = google_compute_subnetwork.workload.id
  network_endpoint_type = "GCE_VM_IP_PORT"
  default_port          = 8080
}

resource "google_compute_network_endpoint" "ep_a" {
  network_endpoint_group = google_compute_network_endpoint_group.neg_a.name
  zone                   = var.zone_a
  instance               = google_compute_instance.be["a"].self_link
  ip_address             = google_compute_address.be["a"].address
  port                   = 8080
}

resource "google_compute_network_endpoint" "ep_a2" {
  network_endpoint_group = google_compute_network_endpoint_group.neg_a.name
  zone                   = var.zone_a
  instance               = google_compute_instance.be["a2"].self_link
  ip_address             = google_compute_address.be["a2"].address
  port                   = 8080
}

resource "google_compute_network_endpoint" "ep_b" {
  network_endpoint_group = google_compute_network_endpoint_group.neg_b.name
  zone                   = var.zone_c
  instance               = google_compute_instance.be["b"].self_link
  ip_address             = google_compute_address.be["b"].address
  port                   = 8080
}

resource "google_compute_region_health_check" "hc_a" {
  name   = "tf-adv-elb08-hc-a"
  region = var.region

  http_health_check {
    port         = 8080
    request_path = "/"
  }
}

resource "google_compute_region_health_check" "hc_b" {
  name   = "tf-adv-elb08-hc-b"
  region = var.region

  http_health_check {
    port         = 8080
    request_path = "/"
  }
}

# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_backend_service
resource "google_compute_region_backend_service" "bs_a" {
  name                  = "tf-adv-elb08-bs-a"
  region                = var.region
  load_balancing_scheme = "EXTERNAL_MANAGED"
  protocol              = "HTTP"
  health_checks         = [google_compute_region_health_check.hc_a.id]

  backend {
    group                 = google_compute_network_endpoint_group.neg_a.id
    balancing_mode        = "RATE"
    max_rate_per_endpoint = 100
    capacity_scaler       = 1.0
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }

  depends_on = [
    google_compute_network_endpoint.ep_a,
    google_compute_network_endpoint.ep_a2,
  ]
}

resource "google_compute_region_backend_service" "bs_b" {
  name                  = "tf-adv-elb08-bs-b"
  region                = var.region
  load_balancing_scheme = "EXTERNAL_MANAGED"
  protocol              = "HTTP"
  health_checks         = [google_compute_region_health_check.hc_b.id]

  backend {
    group                 = google_compute_network_endpoint_group.neg_b.id
    balancing_mode        = "RATE"
    max_rate_per_endpoint = 100
    capacity_scaler       = 1.0
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }

  depends_on = [google_compute_network_endpoint.ep_b]
}

resource "google_compute_region_url_map" "urlmap_81" {
  name            = "tf-adv-elb08-um-81"
  region          = var.region
  default_service = google_compute_region_backend_service.bs_a.id
}

resource "google_compute_region_url_map" "urlmap_82" {
  name            = "tf-adv-elb08-um-82"
  region          = var.region
  default_service = google_compute_region_backend_service.bs_b.id
}

resource "google_compute_region_target_http_proxy" "proxy_81" {
  name    = "tf-adv-elb08-tp-81"
  region  = var.region
  url_map = google_compute_region_url_map.urlmap_81.id
}

resource "google_compute_region_target_http_proxy" "proxy_82" {
  name    = "tf-adv-elb08-tp-82"
  region  = var.region
  url_map = google_compute_region_url_map.urlmap_82.id
}

resource "google_compute_address" "vip" {
  name         = "tf-adv-elb08-vip"
  region       = var.region
  address_type = "EXTERNAL"
  network_tier = "PREMIUM"
}

# Same VIP, two forwarding rules. :81 -> bs_a, :82 -> bs_b.
# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_forwarding_rule
resource "google_compute_forwarding_rule" "fr_81" {
  name                  = "tf-adv-elb08-fr-81"
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

resource "google_compute_forwarding_rule" "fr_82" {
  name                  = "tf-adv-elb08-fr-82"
  region                = var.region
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_protocol           = "TCP"
  port_range            = "82"
  ip_address            = google_compute_address.vip.address
  target                = google_compute_region_target_http_proxy.proxy_82.id
  network_tier          = "PREMIUM"
  network               = google_compute_network.vpc.id

  depends_on = [google_compute_subnetwork.proxy_only]
}

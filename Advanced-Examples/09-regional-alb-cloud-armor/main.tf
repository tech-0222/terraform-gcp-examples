data "google_compute_image" "debian" {
  family  = "debian-12"
  project = "debian-cloud"
}

resource "google_compute_address" "be" {
  name         = "tf-adv-elb09-be-ip"
  region       = var.region
  address_type = "INTERNAL"
  subnetwork   = google_compute_subnetwork.workload.id
}

resource "google_compute_instance" "be" {
  name         = "tf-adv-elb09-be"
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
    network_ip = google_compute_address.be.address
  }

  metadata = {
    startup-script = file("${path.module}/scripts/startup-a.sh")
  }

  labels = {
    env        = "test"
    system     = "tf-examples"
    component  = "alb"
    managed_by = "terraform"
    example    = "09-regional-alb-cloud-armor"
  }

  allow_stopping_for_update = true

  depends_on = [
    google_compute_router_nat.nat,
    google_compute_firewall.allow_health_check,
    google_compute_firewall.allow_proxies,
  ]
}

resource "google_compute_network_endpoint_group" "neg" {
  name                  = "tf-adv-elb09-neg"
  zone                  = var.zone
  network               = google_compute_network.vpc.id
  subnetwork            = google_compute_subnetwork.workload.id
  network_endpoint_type = "GCE_VM_IP_PORT"
  default_port          = 8080
}

resource "google_compute_network_endpoint" "ep" {
  network_endpoint_group = google_compute_network_endpoint_group.neg.name
  zone                   = var.zone
  instance               = google_compute_instance.be.self_link
  ip_address             = google_compute_address.be.address
  port                   = 8080
}

resource "google_compute_region_health_check" "hc" {
  name   = "tf-adv-elb09-hc"
  region = var.region

  http_health_check {
    port         = 8080
    request_path = "/"
  }
}

# Regional policy for regional ALB. Evaluate client source IP before backend.
# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_security_policy
resource "google_compute_region_security_policy" "armor" {
  name        = "tf-adv-elb09-armor"
  region      = var.region
  description = "Allow listed source IPs only."

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_region_security_policy_rule" "allowlist" {
  region          = var.region
  security_policy = google_compute_region_security_policy.armor.name
  priority        = 1000
  action          = "allow"
  description     = "Allow listed client IPs."

  match {
    versioned_expr = "SRC_IPS_V1"
    config {
      src_ip_ranges = var.allowed_src_ips
    }
  }
}

resource "google_compute_region_security_policy_rule" "default_deny" {
  region          = var.region
  security_policy = google_compute_region_security_policy.armor.name
  priority        = 2147483647
  action          = "deny(403)"
  description     = "Default deny."

  match {
    versioned_expr = "SRC_IPS_V1"
    config {
      src_ip_ranges = ["*"]
    }
  }
}

resource "google_compute_region_backend_service" "bs" {
  name                  = "tf-adv-elb09-bs"
  region                = var.region
  load_balancing_scheme = "EXTERNAL_MANAGED"
  protocol              = "HTTP"
  health_checks         = [google_compute_region_health_check.hc.id]
  security_policy       = google_compute_region_security_policy.armor.self_link

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

resource "google_compute_region_url_map" "urlmap" {
  name            = "tf-adv-elb09-um"
  region          = var.region
  default_service = google_compute_region_backend_service.bs.id
}

resource "google_compute_region_target_http_proxy" "proxy" {
  name    = "tf-adv-elb09-tp"
  region  = var.region
  url_map = google_compute_region_url_map.urlmap.id
}

resource "google_compute_address" "vip" {
  name         = "tf-adv-elb09-vip"
  region       = var.region
  address_type = "EXTERNAL"
  network_tier = "PREMIUM"
}

resource "google_compute_forwarding_rule" "fr" {
  name                  = "tf-adv-elb09-fr-80"
  region                = var.region
  load_balancing_scheme = "EXTERNAL_MANAGED"
  ip_protocol           = "TCP"
  port_range            = "80"
  ip_address            = google_compute_address.vip.address
  target                = google_compute_region_target_http_proxy.proxy.id
  network_tier          = "PREMIUM"
  network               = google_compute_network.vpc.id

  depends_on = [google_compute_subnetwork.proxy_only]
}

resource "google_compute_instance" "deny_client" {
  count        = var.create_deny_client ? 1 : 0
  name         = "tf-adv-elb09-deny-client"
  zone         = var.zone
  machine_type = "e2-micro"
  tags         = ["iap-ssh"]

  boot_disk {
    initialize_params {
      image = data.google_compute_image.debian.self_link
      size  = 10
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.workload.id
    access_config {}
  }

  labels = {
    env        = "test"
    system     = "tf-examples"
    component  = "alb"
    managed_by = "terraform"
    example    = "09-regional-alb-cloud-armor"
  }

  allow_stopping_for_update = true
}

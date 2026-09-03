# Global external Application Load Balancer whose backend is a standalone
# zonal NEG created by GKE -- not by Terraform.
#
# The NEG is created by the GKE NEG controller from the Service's
# cloud.google.com/neg annotation (see k8s/neg-app.yaml). Terraform only
# *reads* it with a data source, which is exactly what makes this example's
# failure modes interesting: Terraform's view of the backend and GKE's view
# of the NEG can drift apart.
#
# Deploy order (two-phase apply):
#   1. terraform apply                    (enable_lb=false, the default)
#   2. kubectl apply -f k8s/neg-app.yaml  -- GKE creates the NEGs
#      wait until the NEGs exist in every zone in var.gke_zones
#   3. terraform apply -var="enable_lb=true"

data "google_compute_network_endpoint_group" "standalone" {
  for_each = var.enable_lb ? toset(var.gke_zones) : toset([])

  name    = var.neg_name
  zone    = each.value
  project = var.project_id
}

resource "google_compute_global_address" "lb_vip" {
  count = var.enable_lb ? 1 : 0

  name         = "${var.cluster_name}-lb-vip"
  address_type = "EXTERNAL"
}

resource "google_compute_health_check" "lb" {
  count = var.enable_lb ? 1 : 0

  name               = "${var.cluster_name}-lb-hc"
  check_interval_sec = 5
  timeout_sec        = 5

  http_health_check {
    # The NEG's endpoints are Pods, whose serving port comes from the NEG
    # itself -- so let the health check follow it rather than hard-coding.
    port_specification = "USE_SERVING_PORT"
  }
}

# The backend block references the NEG through the data source above. If
# the NEG is deleted and re-created (even with the same name) this
# association is NOT restored on its own -- re-running terraform apply is
# what puts the backend back. That is the core finding this example
# demonstrates.
resource "google_compute_backend_service" "lb" {
  count = var.enable_lb ? 1 : 0

  name                  = "${var.cluster_name}-bes"
  protocol              = "HTTP"
  timeout_sec           = 30
  load_balancing_scheme = "EXTERNAL"
  health_checks         = [google_compute_health_check.lb[0].id]

  dynamic "backend" {
    for_each = toset(var.gke_zones)
    content {
      group                 = data.google_compute_network_endpoint_group.standalone[backend.value].id
      balancing_mode        = "RATE"
      max_rate_per_endpoint = 100
    }
  }

  depends_on = [google_compute_firewall.allow_lb_health_check]
}

resource "google_compute_url_map" "lb" {
  count = var.enable_lb ? 1 : 0

  name            = "${var.cluster_name}-url-map"
  default_service = google_compute_backend_service.lb[0].id
}

resource "google_compute_target_http_proxy" "lb" {
  count = var.enable_lb ? 1 : 0

  name    = "${var.cluster_name}-http-proxy"
  url_map = google_compute_url_map.lb[0].id
}

resource "google_compute_global_forwarding_rule" "lb" {
  count = var.enable_lb ? 1 : 0

  name                  = "${var.cluster_name}-http-fr"
  target                = google_compute_target_http_proxy.lb[0].id
  port_range            = "80"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL"
  ip_address            = google_compute_global_address.lb_vip[0].self_link
}

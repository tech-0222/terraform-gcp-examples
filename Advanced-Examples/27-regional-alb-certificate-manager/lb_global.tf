# グローバル外部 Application Load Balancer。LB 認証を試すためだけに置く。
#
# バックエンドはリージョン側と同じゾーン NEG を共用する。

resource "google_compute_global_address" "global_lb" {
  count = var.enable_global_lb ? 1 : 0

  name = "tf-adv-cm27-global-ip"
}

resource "google_compute_health_check" "global_http" {
  count = var.enable_global_lb ? 1 : 0

  name = "tf-adv-cm27-global-hc"

  http_health_check {
    port = 80
  }
}

resource "google_compute_backend_service" "global" {
  count = var.enable_global_lb ? 1 : 0

  name                  = "tf-adv-cm27-global-bes"
  protocol              = "HTTP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  health_checks         = [google_compute_health_check.global_http[0].id]

  backend {
    group                 = google_compute_network_endpoint_group.backend.id
    balancing_mode        = "RATE"
    max_rate_per_endpoint = 100
    capacity_scaler       = 1.0
  }
}

resource "google_compute_url_map" "global" {
  count = var.enable_global_lb ? 1 : 0

  name            = "tf-adv-cm27-global-urlmap"
  default_service = google_compute_backend_service.global[0].id
}

# グローバル側は証明書マップを指す。リージョン側の
# certificate_manager_certificates とは別の入り口になる。
resource "google_compute_target_https_proxy" "global" {
  count = var.enable_global_lb ? 1 : 0

  name            = "tf-adv-cm27-global-proxy"
  url_map         = google_compute_url_map.global[0].id
  certificate_map = "//certificatemanager.googleapis.com/${google_certificate_manager_certificate_map.global[0].id}"
}

resource "google_compute_global_forwarding_rule" "global" {
  count = var.enable_global_lb ? 1 : 0

  name                  = "tf-adv-cm27-global-fr"
  ip_address            = google_compute_global_address.global_lb[0].address
  port_range            = "443"
  target                = google_compute_target_https_proxy.global[0].id
  load_balancing_scheme = "EXTERNAL_MANAGED"
}

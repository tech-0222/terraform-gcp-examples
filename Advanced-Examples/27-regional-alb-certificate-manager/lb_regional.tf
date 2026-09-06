# リージョン外部 Application Load Balancer。
#
# Compute Engine のマネージド SSL 証明書は、ここでは使えない。
#
# 「Compute Engine Google-managed SSL certificates aren't supported for
#   regional external Application Load Balancers, regional internal
#   Application Load Balancers, or cross-region internal Application Load
#   Balancers.」
#
# つまりリージョン ALB で Google 発行の証明書を使うなら、Certificate Manager
# が唯一の選択肢になる。
# Ref: https://cloud.google.com/load-balancing/docs/ssl-certificates/google-managed-certs

resource "google_compute_address" "regional_lb" {
  name         = "tf-adv-cm27-regional-ip"
  region       = var.region
  address_type = "EXTERNAL"
  network_tier = "STANDARD"
}

resource "google_compute_region_health_check" "http" {
  name   = "tf-adv-cm27-hc"
  region = var.region

  http_health_check {
    port = 80
  }
}

resource "google_compute_region_backend_service" "regional" {
  name                  = "tf-adv-cm27-regional-bes"
  region                = var.region
  protocol              = "HTTP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  health_checks         = [google_compute_region_health_check.http.id]

  backend {
    group                 = google_compute_network_endpoint_group.backend.id
    balancing_mode        = "RATE"
    max_rate_per_endpoint = 100
    capacity_scaler       = 1.0
  }
}

resource "google_compute_region_url_map" "regional" {
  name            = "tf-adv-cm27-regional-urlmap"
  region          = var.region
  default_service = google_compute_region_backend_service.regional.id
}

# certificate_manager_certificates に直接アタッチする。証明書マップは使わない。
#
# 「To deploy the regional Google-managed certificate to a regional external
#   Application Load Balancer or regional internal Application Load Balancer,
#   attach it directly to the target proxy.」
#
# ssl_certificates とは併用できない。
# 「sslCertificates and certificateManagerCertificates can't be defined together.」
resource "google_compute_region_target_https_proxy" "regional" {
  name                             = "tf-adv-cm27-regional-proxy"
  region                           = var.region
  url_map                          = google_compute_region_url_map.regional.id
  certificate_manager_certificates = [google_certificate_manager_certificate.regional.id]
}

resource "google_compute_forwarding_rule" "regional" {
  name                  = "tf-adv-cm27-regional-fr"
  region                = var.region
  ip_address            = google_compute_address.regional_lb.address
  ip_protocol           = "TCP"
  port_range            = "443"
  target                = google_compute_region_target_https_proxy.regional.id
  load_balancing_scheme = "EXTERNAL_MANAGED"
  network               = google_compute_network.vpc.id
  network_tier          = "STANDARD"

  depends_on = [google_compute_subnetwork.proxy_only]
}

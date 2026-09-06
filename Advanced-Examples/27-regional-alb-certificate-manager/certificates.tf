# 認証方式を2つ並べる。
#
#   A. DNS 認証  + リージョン証明書 -> リージョン外部 ALB
#   B. LB 認証   + グローバル証明書 -> グローバル外部 ALB
#
# B をリージョンでやることはできない。LB 認証が対応するのは
# 「Global external Application Load Balancer / Classic Application Load
#  Balancer / Global external proxy Network Load Balancer / Classic proxy
#  Network Load Balancer」だけ。
# Ref: https://cloud.google.com/certificate-manager/docs/deploy-google-managed-lb-auth

# --- A. DNS 認証（リージョン）-------------------------------------------

# リージョン証明書には、同じリージョンの DNS 認証が要る。
#
# 「For regional Google-managed certificates, you must create a regional DNS
#   authorization in the same region as the certificate. You can't use global
#   DNS authorizations with regional certificates.」
#
# さらに種別も選べない。
#
# 「For regional Google-managed certificates, you can create only the
#   PER_PROJECT_RECORD type of DNS authorization.」
#
# global 既定の FIXED_RECORD とは CNAME の名前が変わる。
# Ref: https://cloud.google.com/certificate-manager/docs/deploy-google-managed-regional
resource "google_certificate_manager_dns_authorization" "regional" {
  name     = "tf-adv-cm27-dnsauth-regional"
  location = var.region
  domain   = local.regional_fqdn

  labels = {
    managed_by = "terraform"
    example    = "27-regional-alb-certificate-manager"
  }

  depends_on = [google_project_service.required]
}

# この証明書は、ロードバランサが無くても発行を開始できるか。
# Cloudflare 側の記載が無いため実測する。
# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/certificate_manager_certificate
resource "google_certificate_manager_certificate" "regional" {
  name     = "tf-adv-cm27-cert-regional"
  location = var.region

  managed {
    domains            = [local.regional_fqdn]
    dns_authorizations = [google_certificate_manager_dns_authorization.regional.id]
  }

  labels = {
    managed_by = "terraform"
    example    = "27-regional-alb-certificate-manager"
  }
}

# --- B. LB 認証（グローバル）--------------------------------------------

# dns_authorizations も issuance_config も指定しない。これが LB 認証。
# 発行には、対象ホスト名の A レコードがこの LB の IP だけを指している必要がある。
resource "google_certificate_manager_certificate" "global" {
  count = var.enable_global_lb ? 1 : 0

  name     = "tf-adv-cm27-cert-global"
  location = "global"

  managed {
    domains = [local.global_fqdn]
  }

  labels = {
    managed_by = "terraform"
    example    = "27-regional-alb-certificate-manager"
  }

  depends_on = [google_project_service.required]
}

# グローバル ALB は証明書マップ経由で証明書を持つ。
# リージョン ALB がターゲットプロキシへ直接アタッチするのと対になる違い。
resource "google_certificate_manager_certificate_map" "global" {
  count = var.enable_global_lb ? 1 : 0

  name = "tf-adv-cm27-map"

  depends_on = [google_project_service.required]
}

resource "google_certificate_manager_certificate_map_entry" "global" {
  count = var.enable_global_lb ? 1 : 0

  name         = "tf-adv-cm27-map-entry"
  map          = google_certificate_manager_certificate_map.global[0].name
  certificates = [google_certificate_manager_certificate.global[0].id]
  hostname     = local.global_fqdn
}

# --- C. LB を一切作らずに DNS 認証だけで発行できるか ----------------------
#
# A のリージョン証明書は、同じ apply でロードバランサも作っている。それでは
# 「LB が無くても発行できる」ことの証明にならない。
#
# ここは A レコードもロードバランサも作らず、DNS 認証の CNAME だけを置く。
# これが ACTIVE になれば、DNS 認証は配信経路と無関係に発行できると言える。
# LB 認証では原理的にできない（LB に向いていることが認証の条件のため）。
resource "google_certificate_manager_dns_authorization" "nolb" {
  name     = "tf-adv-cm27-dnsauth-nolb"
  location = var.region
  domain   = "nolb.${var.dns_zone_domain}"

  depends_on = [google_project_service.required]
}

resource "google_certificate_manager_certificate" "nolb" {
  name     = "tf-adv-cm27-cert-nolb"
  location = var.region

  managed {
    domains            = ["nolb.${var.dns_zone_domain}"]
    dns_authorizations = [google_certificate_manager_dns_authorization.nolb.id]
  }
}

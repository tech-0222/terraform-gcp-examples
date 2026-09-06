# 委任されたサブドメインを Cloud DNS で持つ。
#
# 親ドメイン側で、このゾーンのネームサーバへ NS を向けておく必要がある。
# ゾーンを作っただけでは権威にならない。
resource "google_dns_managed_zone" "delegated" {
  name        = replace(var.dns_zone_domain, ".", "-")
  dns_name    = "${var.dns_zone_domain}."
  description = "27-regional-alb-certificate-manager"

  labels = {
    managed_by = "terraform"
    example    = "27-regional-alb-certificate-manager"
  }

  depends_on = [google_project_service.required]
}

locals {
  regional_fqdn = "${var.regional_hostname}.${var.dns_zone_domain}"
  global_fqdn   = "${var.global_hostname}.${var.dns_zone_domain}"
}

# DNS 認証の CNAME。レコード名も値も、認証リソースの出力から取る。
#
# リージョン証明書では PER_PROJECT_RECORD しか選べず、名前が
# _acme-challenge_<プロジェクト固有の接尾辞>.<ドメイン> になる。
# global の FIXED_RECORD（_acme-challenge.<ドメイン>）とは別物なので、
# 名前を決め打ちにしない。
resource "google_dns_record_set" "acme_challenge_regional" {
  name         = google_certificate_manager_dns_authorization.regional.dns_resource_record[0].name
  type         = google_certificate_manager_dns_authorization.regional.dns_resource_record[0].type
  ttl          = 300
  managed_zone = google_dns_managed_zone.delegated.name

  rrdatas = [google_certificate_manager_dns_authorization.regional.dns_resource_record[0].data]
}

# LB 認証には CNAME が要らない。代わりに、そのホスト名の A レコードが
# ロードバランサの IP だけを指している必要がある。
resource "google_dns_record_set" "global_a" {
  count = var.enable_global_lb ? 1 : 0

  name         = "${local.global_fqdn}."
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.delegated.name

  rrdatas = [google_compute_global_address.global_lb[0].address]
}

# リージョン側は、証明書の発行に A レコードを必要としない。
# 発行できたあと、実際に TLS を張って確かめるために置く。
resource "google_dns_record_set" "regional_a" {
  name         = "${local.regional_fqdn}."
  type         = "A"
  ttl          = 300
  managed_zone = google_dns_managed_zone.delegated.name

  rrdatas = [google_compute_address.regional_lb.address]
}

# C 用の CNAME。A レコードは作らない。
resource "google_dns_record_set" "acme_challenge_nolb" {
  name         = google_certificate_manager_dns_authorization.nolb.dns_resource_record[0].name
  type         = google_certificate_manager_dns_authorization.nolb.dns_resource_record[0].type
  ttl          = 300
  managed_zone = google_dns_managed_zone.delegated.name

  rrdatas = [google_certificate_manager_dns_authorization.nolb.dns_resource_record[0].data]
}

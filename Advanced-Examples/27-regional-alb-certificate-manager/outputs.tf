# 親ドメイン側の NS レコードに貼る。委任しないと DNS 認証は完了しない。
output "name_servers" {
  value       = google_dns_managed_zone.delegated.name_servers
  description = "委任先のネームサーバ。親ドメインの NS レコードに設定する"
}

output "dns_zone_domain" {
  value = var.dns_zone_domain
}

output "regional_fqdn" {
  value       = local.regional_fqdn
  description = "DNS 認証 + リージョン外部 ALB のホスト名"
}

output "global_fqdn" {
  value       = var.enable_global_lb ? local.global_fqdn : null
  description = "LB 認証 + グローバル外部 ALB のホスト名"
}

output "regional_lb_ip" {
  value = google_compute_address.regional_lb.address
}

output "global_lb_ip" {
  value = var.enable_global_lb ? google_compute_global_address.global_lb[0].address : null
}

# 認証方式の違いが一番はっきり出る箇所。
# DNS 認証は CNAME を要求し、LB 認証は要求しない。
output "dns_authorization_record" {
  value = {
    name = google_certificate_manager_dns_authorization.regional.dns_resource_record[0].name
    type = google_certificate_manager_dns_authorization.regional.dns_resource_record[0].type
    data = google_certificate_manager_dns_authorization.regional.dns_resource_record[0].data
  }
  description = "リージョン DNS 認証が要求する CNAME。Cloud DNS へは自動で登録される"
}

output "vip" {
  description = "Regional external Application Load Balancer VIP."
  value       = google_compute_address.vip.address
}

output "curl_generated_cookie" {
  description = "Port 81 GENERATED_COOKIE. First response should Set-Cookie GCLB=..."
  value       = <<-EOT
    VIP=$(terraform output -raw vip)
    curl -si "http://$${VIP}:81/" | grep -i set-cookie
    TMP=$(mktemp)
    curl -s -c "$TMP" "http://$${VIP}:81/" >/dev/null
    for i in 1 2 3 4 5; do curl -s -b "$TMP" "http://$${VIP}:81/"; echo; done
    rm -f "$TMP"
  EOT
}

output "curl_http_cookie" {
  description = "Port 83 HTTP_COOKIE named ROUTE."
  value       = <<-EOT
    VIP=$(terraform output -raw vip)
    curl -si "http://$${VIP}:83/" | grep -i set-cookie
    TMP=$(mktemp)
    curl -s -c "$TMP" "http://$${VIP}:83/" >/dev/null
    for i in 1 2 3 4 5; do curl -s -b "$TMP" "http://$${VIP}:83/"; echo; done
    rm -f "$TMP"
  EOT
}

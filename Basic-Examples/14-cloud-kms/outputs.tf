output "project_id" {
  description = "Google Cloud Project ID."
  value       = var.project_id
}

output "location" {
  description = "Cloud KMS location."
  value       = var.location
}

output "key_ring_name" {
  description = "Cloud KMS KeyRing name."
  value       = google_kms_key_ring.example.name
}

output "key_ring_id" {
  description = "Cloud KMS KeyRing resource ID."
  value       = google_kms_key_ring.example.id
}

output "crypto_key_name" {
  description = "Cloud KMS CryptoKey name."
  value       = google_kms_crypto_key.example.name
}

output "crypto_key_id" {
  description = "Cloud KMS CryptoKey resource ID."
  value       = google_kms_crypto_key.example.id
}

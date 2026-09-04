# Cloud KMS key used to encrypt the GKE node boot disks (CMEK).
#
# IMPORTANT: key rings and crypto keys CANNOT be deleted in Google Cloud.
# `terraform destroy` only drops them from state; the objects stay in the
# project forever. Re-applying with the same names therefore fails with
# 409 AlreadyExists. See README ("2回目以降の実行") for the import command.

# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_service
resource "google_project_service" "kms" {
  project = var.project_id
  service = "cloudkms.googleapis.com"

  disable_on_destroy = false
}

data "google_project" "current" {
  project_id = var.project_id
}

# The key ring location must match the region the nodes run in. A key in
# another location cannot encrypt disks here.
# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_key_ring
resource "google_kms_key_ring" "boot_disk" {
  name     = var.kms_key_ring_name
  location = var.region

  depends_on = [google_project_service.kms]
}

# No rotation_period: this example rotates the key by hand
# (`gcloud kms keys versions create --primary`) so the timing is observable.
# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_crypto_key
resource "google_kms_crypto_key" "boot_disk" {
  name     = var.kms_crypto_key_name
  key_ring = google_kms_key_ring.boot_disk.id
  purpose  = "ENCRYPT_DECRYPT"

  lifecycle {
    # Deletion is impossible anyway; this only removes it from state.
    prevent_destroy = false
  }
}

# The boot disk is created by Compute Engine, not by GKE, so the Compute
# Engine service agent is the one that has to use the key. Without this
# binding the node pool fails to create.
# Ref: https://cloud.google.com/kubernetes-engine/docs/how-to/using-cmek
resource "google_kms_crypto_key_iam_member" "compute_agent" {
  crypto_key_id = google_kms_crypto_key.boot_disk.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.current.number}@compute-system.iam.gserviceaccount.com"
}

# The GKE service agent also touches the key when it manages node pools.
resource "google_kms_crypto_key_iam_member" "container_agent" {
  crypto_key_id = google_kms_crypto_key.boot_disk.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.current.number}@container-engine-robot.iam.gserviceaccount.com"
}

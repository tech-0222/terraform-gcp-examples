output "subject_sa" {
  value = google_service_account.subject.email
}

output "terraform_sa" {
  value = google_service_account.terraform.email
}

output "vm_runtime_sa" {
  value = google_service_account.vm_runtime.email
}

output "bucket" {
  value = google_storage_bucket.lab.name
}

output "subnet" {
  value = google_compute_subnetwork.lab.self_link
}

output "create_only_role" {
  value = google_project_iam_custom_role.create_only.name
}

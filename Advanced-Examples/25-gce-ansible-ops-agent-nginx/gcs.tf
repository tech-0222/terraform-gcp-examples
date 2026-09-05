# Bucket holding the Ansible assets.
#
# The VM's startup script syncs this bucket and runs ansible-playbook against
# what it finds. That creates an ordering dependency Terraform cannot see: the
# playbook must be in the bucket before the VM boots, but Terraform has no way
# to know the startup script reads from it.
#
# This example makes the dependency explicit with depends_on and by uploading
# the playbook through google_storage_bucket_object, so a single `apply` works.
# The README shows what happens without that.
resource "google_storage_bucket" "ansible" {
  name     = "${var.bucket_prefix}-${var.project_id}"
  location = var.region

  uniform_bucket_level_access = true

  # A verification bucket. Without this, destroy fails once the startup script
  # has written anything into it.
  force_destroy = true

  labels = {
    env        = "test"
    system     = "tf-examples"
    managed_by = "terraform"
    example    = "25-gce-ansible-ops-agent-nginx"
  }

  depends_on = [google_project_service.required]
}

# Every file under ansible/ becomes an object. fileset keeps the two in step:
# adding a role file needs no Terraform change.
resource "google_storage_bucket_object" "ansible" {
  for_each = fileset("${path.module}/ansible", "**")

  name   = "ansible/${each.value}"
  bucket = google_storage_bucket.ansible.name
  source = "${path.module}/ansible/${each.value}"

  # detect_md5hash makes a changed file replace the object, which is what lets
  # `terraform apply` push a playbook edit.
  detect_md5hash = filemd5("${path.module}/ansible/${each.value}")
}

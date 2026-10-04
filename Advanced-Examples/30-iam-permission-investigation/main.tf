locals {
  services = [
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "compute.googleapis.com",
    "storage.googleapis.com",
    "cloudasset.googleapis.com",
    "policyanalyzer.googleapis.com",
    "policytroubleshooter.googleapis.com",
    "policysimulator.googleapis.com",
    "recommender.googleapis.com",
  ]

  compute_roles = {
    create_only    = google_project_iam_custom_role.create_only.name
    instance_admin = "roles/compute.instanceAdmin.v1"
  }
}

resource "google_project_service" "this" {
  for_each = toset(local.services)

  service            = each.value
  disable_on_destroy = false
}

# ---------------------------------------------------------------------------
# Principal
# ---------------------------------------------------------------------------

# gcloud / REST API で操作する検証用 Principal
resource "google_service_account" "subject" {
  account_id   = "tf-adv-iam-subject"
  display_name = "IAM lab: gcloud / REST API subject"

  depends_on = [google_project_service.this]
}

# executor/ の Terraform を実行する Principal
resource "google_service_account" "terraform" {
  account_id   = "tf-adv-iam-terraform"
  display_name = "IAM lab: Terraform executor"

  depends_on = [google_project_service.this]
}

# VM に付与する Runtime SA。Role は付けない（VM から何かにアクセスする検証はしない）
resource "google_service_account" "vm_runtime" {
  account_id   = "tf-adv-iam-vm-runtime"
  display_name = "IAM lab: VM runtime"

  depends_on = [google_project_service.this]
}

# 操作者が検証用 SA を借用できるようにする。付与先は SA 単位
resource "google_service_account_iam_member" "operator_impersonate" {
  for_each = {
    subject   = google_service_account.subject.name
    terraform = google_service_account.terraform.name
  }

  service_account_id = each.value
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = var.operator_member
}

# ---------------------------------------------------------------------------
# Cloud Storage
# ---------------------------------------------------------------------------

resource "google_storage_bucket" "lab" {
  name                        = "${var.project_id}-tf-adv-iam"
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true

  depends_on = [google_project_service.this]
}

resource "google_storage_bucket_object" "hello" {
  bucket  = google_storage_bucket.lab.name
  name    = "hello.txt"
  content = "hello from tf-adv-iam\n"
}

resource "google_storage_bucket_iam_member" "subject" {
  count = var.subject_bucket_role == "" ? 0 : 1

  bucket = google_storage_bucket.lab.name
  role   = var.subject_bucket_role
  member = google_service_account.subject.member
}

resource "google_storage_bucket_iam_member" "console" {
  count = var.console_member != "" && var.console_bucket_role != "" ? 1 : 0

  bucket = google_storage_bucket.lab.name
  role   = var.console_bucket_role
  member = var.console_member
}

resource "google_project_iam_member" "console" {
  count = var.console_member != "" && var.console_project_role != "" ? 1 : 0

  project = var.project_id
  role    = var.console_project_role
  member  = var.console_member
}

# ---------------------------------------------------------------------------
# Compute Engine
# ---------------------------------------------------------------------------

# compute.instances.create から始めるロール。VM 作成に関連する Permission を
# エラーから1つずつ見つけて create_only_extra_permissions に足していく測定器で、運用で使うものではない
resource "google_project_iam_custom_role" "create_only" {
  role_id     = "tfAdvIamCreateOnly"
  title       = "IAM lab: compute.instances.create and discovered permissions"
  permissions = concat(["compute.instances.create"], var.create_only_extra_permissions)

  depends_on = [google_project_service.this]
}

resource "google_project_iam_member" "subject_compute" {
  count = var.subject_compute_role == "none" ? 0 : 1

  project = var.project_id
  role    = local.compute_roles[var.subject_compute_role]
  member  = google_service_account.subject.member
}

resource "google_project_iam_member" "terraform_compute" {
  count = var.terraform_compute_role == "none" ? 0 : 1

  project = var.project_id
  role    = local.compute_roles[var.terraform_compute_role]
  member  = google_service_account.terraform.member
}

# Runtime SA を VM に付けるための actAs。付与先はプロジェクトでなく Runtime SA
resource "google_service_account_iam_member" "subject_act_as_runtime" {
  count = var.subject_can_act_as_runtime ? 1 : 0

  service_account_id = google_service_account.vm_runtime.name
  role               = "roles/iam.serviceAccountUser"
  member             = google_service_account.subject.member
}

resource "google_service_account_iam_member" "terraform_act_as_runtime" {
  count = var.terraform_can_act_as_runtime ? 1 : 0

  service_account_id = google_service_account.vm_runtime.name
  role               = "roles/iam.serviceAccountUser"
  member             = google_service_account.terraform.member
}

# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_service
resource "google_project_service" "bigquery" {
  project = var.project_id
  service = "bigquery.googleapis.com"

  disable_on_destroy = false
}

# BigQuery Terraform operations also use Cloud Resource Manager APIs.
resource "google_project_service" "cloudresourcemanager" {
  project = var.project_id
  service = "cloudresourcemanager.googleapis.com"

  disable_on_destroy = false
}

# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/bigquery_dataset
resource "google_bigquery_dataset" "example" {
  project                    = var.project_id
  dataset_id                 = var.dataset_id
  friendly_name              = "Terraform Example Dataset"
  description                = "Dataset created by terraform-gcp-examples."
  location                   = var.location
  delete_contents_on_destroy = var.delete_contents_on_destroy

  labels = {
    env        = "test"
    system     = "tf-examples"
    component  = "bigquery"
    managed_by = "terraform"
    example    = "12-bigquery"
  }

  depends_on = [
    google_project_service.bigquery,
    google_project_service.cloudresourcemanager,
  ]
}

# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/bigquery_table
resource "google_bigquery_table" "example" {
  project             = var.project_id
  dataset_id          = google_bigquery_dataset.example.dataset_id
  table_id            = var.table_id
  description         = "Example table for Terraform verification."
  deletion_protection = false

  schema = jsonencode([
    {
      name        = "id"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Record ID"
    },
    {
      name        = "message"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Example message"
    },
    {
      name        = "created_at"
      type        = "TIMESTAMP"
      mode        = "NULLABLE"
      description = "Creation timestamp"
    },
  ])

  labels = {
    env        = "test"
    system     = "tf-examples"
    component  = "bigquery"
    managed_by = "terraform"
    example    = "12-bigquery"
  }
}

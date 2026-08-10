# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_service
resource "google_project_service" "sqladmin" {
  project = var.project_id
  service = "sqladmin.googleapis.com"

  disable_on_destroy = false
}

# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database_instance
resource "google_sql_database_instance" "example" {
  project          = var.project_id
  name             = var.instance_name
  region           = var.region
  database_version = var.database_version

  # Learning sample: allow Terraform to delete the instance.
  deletion_protection = false

  settings {
    tier              = var.tier
    edition           = "ENTERPRISE"
    availability_type = "ZONAL"
    disk_type         = "PD_SSD"
    disk_size         = var.disk_size_gb
    disk_autoresize   = false

    backup_configuration {
      enabled = false
    }

    ip_configuration {
      ipv4_enabled = true
    }

    user_labels = {
      env        = "test"
      system     = "tf-examples"
      component  = "cloud-sql"
      managed_by = "terraform"
      example    = "13-cloud-sql-postgresql"
    }
  }

  depends_on = [google_project_service.sqladmin]
}

# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database
resource "google_sql_database" "example" {
  project  = var.project_id
  name     = var.database_name
  instance = google_sql_database_instance.example.name
}

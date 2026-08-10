# Enable only the APIs required by this scenario.
resource "google_project_service" "required" {
  for_each = toset([
    "artifactregistry.googleapis.com",
    "iam.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "sqladmin.googleapis.com",
  ])

  project = var.project_id
  service = each.value

  disable_on_destroy = false
}

resource "google_artifact_registry_repository" "app" {
  project       = var.project_id
  location      = var.region
  repository_id = var.repository_id
  description   = "Cloud Run + Cloud SQL sample application images"
  format        = "DOCKER"

  labels = {
    env        = "test"
    system     = "tf-examples"
    component  = "artifact-registry"
    managed_by = "terraform"
    example    = "06-cloudrun-cloudsql-postgresql"
  }

  depends_on = [google_project_service.required]
}

resource "google_sql_database_instance" "postgres" {
  project          = var.project_id
  name             = var.instance_name
  region           = var.region
  database_version = var.database_version

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

    # Public IP is enabled for the Cloud SQL Auth Proxy path used by Cloud Run.
    # No authorized_networks are needed for the Cloud Run Unix socket connection.
    ip_configuration {
      ipv4_enabled = true
    }

    user_labels = {
      env        = "test"
      system     = "tf-examples"
      component  = "cloud-sql"
      managed_by = "terraform"
      example    = "06-cloudrun-cloudsql-postgresql"
    }
  }

  depends_on = [google_project_service.required]
}

resource "google_sql_database" "app" {
  project  = var.project_id
  name     = var.database_name
  instance = google_sql_database_instance.postgres.name
}

# Terraform 1.11+ write-only argument avoids persisting the password in raw plan/state.
# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_user
resource "google_sql_user" "app" {
  project             = var.project_id
  name                = var.db_user
  instance            = google_sql_database_instance.postgres.name
  password_wo         = var.db_password
  password_wo_version = var.db_password_version
}

resource "google_cloud_run_v2_service" "app" {
  project  = var.project_id
  name     = var.service_name
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  deletion_protection = false

  template {
    service_account = google_service_account.run.email

    containers {
      image = var.container_image

      env {
        name  = "DB_NAME"
        value = google_sql_database.app.name
      }

      env {
        name  = "DB_USER"
        value = google_sql_user.app.name
      }

      env {
        name  = "INSTANCE_UNIX_SOCKET"
        value = "/cloudsql/${google_sql_database_instance.postgres.connection_name}"
      }

      env {
        name = "DB_PASSWORD"

        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.db_password.secret_id
            version = google_secret_manager_secret_version.db_password.version
          }
        }
      }

      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }
    }

    volumes {
      name = "cloudsql"

      cloud_sql_instance {
        instances = [google_sql_database_instance.postgres.connection_name]
      }
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 2
    }
  }

  labels = {
    env        = "test"
    system     = "tf-examples"
    component  = "cloudrun"
    managed_by = "terraform"
    example    = "06-cloudrun-cloudsql-postgresql"
  }

  depends_on = [
    google_project_iam_member.run_cloudsql_client,
    google_secret_manager_secret_iam_member.run_secret_accessor,
    google_artifact_registry_repository_iam_member.run_reader,
    google_secret_manager_secret_version.db_password,
    google_sql_user.app,
  ]
}

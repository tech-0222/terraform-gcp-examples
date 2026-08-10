# Kubernetes resources that prove Workload Identity can write to GCS.

resource "kubernetes_namespace_v1" "demo" {
  metadata {
    name = var.k8s_namespace
  }

  depends_on = [google_container_node_pool.spot]
}

# Ref: https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account_v1
resource "kubernetes_service_account_v1" "gcs" {
  metadata {
    name      = var.k8s_service_account
    namespace = kubernetes_namespace_v1.demo.metadata[0].name

    annotations = {
      "iam.gke.io/gcp-service-account" = google_service_account.gcs.email
    }
  }
}

# One-shot Job: write an object using Application Default Credentials from WI.
# Ref: https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/job_v1
resource "kubernetes_job_v1" "gcs_write" {
  metadata {
    name      = "wi-gcs-write"
    namespace = kubernetes_namespace_v1.demo.metadata[0].name
  }

  spec {
    backoff_limit = 3

    template {
      metadata {
        labels = {
          app = "wi-gcs-write"
        }
      }

      spec {
        service_account_name = kubernetes_service_account_v1.gcs.metadata[0].name
        restart_policy       = "Never"

        container {
          name  = "writer"
          image = "gcr.io/google.com/cloudsdktool/google-cloud-cli:slim"

          command = [
            "bash",
            "-c",
            "set -euo pipefail; echo \"hello-from-workload-identity\" | gsutil cp - \"gs://${google_storage_bucket.demo.name}/${var.object_name}\"; gsutil cat \"gs://${google_storage_bucket.demo.name}/${var.object_name}\"",
          ]
        }
      }
    }
  }

  wait_for_completion = true

  timeouts {
    create = "15m"
    update = "15m"
  }

  depends_on = [
    google_storage_bucket_iam_member.gcs_writer,
    google_service_account_iam_member.workload_identity_user,
    kubernetes_service_account_v1.gcs,
  ]
}

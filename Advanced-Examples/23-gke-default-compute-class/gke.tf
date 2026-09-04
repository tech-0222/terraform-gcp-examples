# GKE Standard with node auto-provisioning (NAP) and the default compute
# class switch.
#
# cluster_autoscaling.default_compute_class_enabled is the Terraform name for
# what the REST API calls clusterAutoscaling.defaultComputeClassConfig.enabled,
# and what the console calls "Autopilot compute class compatibility". Three
# names, one switch.
#
# It is NOT enable_autopilot. That makes the whole cluster Autopilot. This one
# stays a Standard cluster and only changes how the autoscaler picks machines
# for Pods that do not ask for anything in particular.

resource "google_service_account" "gke_node" {
  account_id   = "${var.cluster_name}-node"
  display_name = "GKE node pool (${var.cluster_name})"
}

resource "google_project_iam_member" "gke_node" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.gke_node.email}"
}

# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.zone

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.gke.name

  remove_default_node_pool = true
  initial_node_count       = 1

  deletion_protection = false

  release_channel {
    channel = "REGULAR"
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = true
    master_ipv4_cidr_block  = var.master_ipv4_cidr_block
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = var.bastion_subnet_cidr
      display_name = "bastion-subnet"
    }
  }

  # Node auto-provisioning. Without this the autoscaler cannot create node
  # pools of its own, and the compute class has nothing to act on.
  # Ref: https://cloud.google.com/kubernetes-engine/docs/how-to/node-auto-provisioning
  cluster_autoscaling {
    enabled = var.enable_node_auto_provisioning

    # The switch under test. Toggling it is what this example is for.
    default_compute_class_enabled = var.default_compute_class_enabled

    dynamic "resource_limits" {
      for_each = var.enable_node_auto_provisioning ? [1] : []
      content {
        resource_type = "cpu"
        minimum       = 0
        maximum       = var.nap_max_cpu
      }
    }

    dynamic "resource_limits" {
      for_each = var.enable_node_auto_provisioning ? [1] : []
      content {
        resource_type = "memory"
        minimum       = 0
        maximum       = var.nap_max_memory_gb
      }
    }

    dynamic "auto_provisioning_defaults" {
      for_each = var.enable_node_auto_provisioning ? [1] : []
      content {
        service_account = google_service_account.gke_node.email
        oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
        disk_size       = 30
        disk_type       = "pd-balanced"

        management {
          auto_repair  = true
          auto_upgrade = true
        }
      }
    }
  }

  resource_labels = {
    env        = "test"
    system     = "tf-examples"
    component  = "gke"
    managed_by = "terraform"
    example    = "23-gke-default-compute-class"
  }

  depends_on = [google_compute_subnetwork.gke]
}

# A small pool so the cluster has somewhere to run system Pods. Anything that
# does not fit here is what makes the autoscaler provision a node, which is
# where the compute class becomes observable.
# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_node_pool
resource "google_container_node_pool" "primary" {
  name     = "${var.cluster_name}-np"
  location = var.zone
  cluster  = google_container_cluster.primary.name

  node_count = var.node_count

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type    = var.node_machine_type
    disk_size_gb    = 30
    disk_type       = "pd-balanced"
    service_account = google_service_account.gke_node.email
    spot            = var.use_spot

    oauth_scopes = ["https://www.googleapis.com/auth/cloud-platform"]

    labels = {
      component  = "gke"
      managed_by = "terraform"
      example    = "23-gke-default-compute-class"
      pool       = "fixed"
    }

    tags = ["gke-${var.cluster_name}"]
  }

  depends_on = [google_project_iam_member.gke_node]
}

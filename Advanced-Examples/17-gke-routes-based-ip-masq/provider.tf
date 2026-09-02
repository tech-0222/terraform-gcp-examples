# Project A: GKE (routes-based) + bastion.
provider "google" {
  project = var.project_id
  region  = var.region
}

# Project B: destination VM only. A separate project makes the VPC Peering
# genuinely cross-project, matching how this pattern shows up in practice
# (peering into a different team's or vendor's VPC).
provider "google" {
  alias   = "b"
  project = var.target_project_id
  region  = var.region
}

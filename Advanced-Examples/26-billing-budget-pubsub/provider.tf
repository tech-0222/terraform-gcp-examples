# billingbudgets.googleapis.com is a user-project-override API: it bills the
# quota to a project you nominate rather than to the resource's own project.
# A budget has no project of its own -- it lives under a billing account --
# so without these two the provider has nothing to charge the quota to and the
# call fails with:
#
#   Error 403: Your application is authenticating by using local Application
#   Default Credentials. The billingbudgets.googleapis.com API requires a
#   quota project, which is not set by default.
#
# Ref: https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/provider_reference#user_project_override
provider "google" {
  project = var.project_id
  region  = var.region

  user_project_override = true
  billing_project       = var.project_id
}

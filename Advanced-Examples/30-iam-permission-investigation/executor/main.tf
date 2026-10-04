# 親ディレクトリで作った tf-adv-iam-terraform を借用して VM を作る。
# 同じ VM 作成でも、Terraform 経路では gcloud と別の Permission が要るかを見る
provider "google" {
  project                     = var.project_id
  region                      = var.region
  zone                        = var.zone
  impersonate_service_account = var.terraform_sa
}

variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "asia-northeast1"
}

variable "zone" {
  type    = string
  default = "asia-northeast1-a"
}

variable "terraform_sa" {
  type        = string
  description = "借用する Terraform 実行 SA（親ディレクトリの output terraform_sa）"
}

variable "vm_runtime_sa" {
  type        = string
  description = "VM に付ける Runtime SA（親ディレクトリの output vm_runtime_sa）"
}

variable "subnet" {
  type        = string
  description = "VM を置くサブネットの self_link（親ディレクトリの output subnet）"
}

resource "google_compute_instance" "lab" {
  name         = "tf-adv-iam-vm-tf"
  machine_type = "e2-micro"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    subnetwork = var.subnet
  }

  service_account {
    email  = var.vm_runtime_sa
    scopes = ["cloud-platform"]
  }

  shielded_instance_config {
    enable_secure_boot = true
  }
}

resource "google_project_service" "required" {
  for_each = toset([
    "compute.googleapis.com",
    "iap.googleapis.com",
    "iam.googleapis.com",
    "oslogin.googleapis.com",
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_service_account" "vm" {
  account_id   = "tf-adv-iap-forward-vm"
  display_name = "Advanced IAP SSH port forwarding VM"
  description  = "Runtime identity for Advanced-Examples/07-iap-ssh-port-forwarding."

  depends_on = [google_project_service.required]
}

data "google_compute_image" "debian" {
  family  = "debian-12"
  project = "debian-cloud"
}

resource "google_compute_instance" "vm" {
  name         = var.instance_name
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["iap-ssh"]

  boot_disk {
    initialize_params {
      image = data.google_compute_image.debian.self_link
      size  = 20
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.primary.id
    # No access_config: the VM has no external IP.
  }

  service_account {
    email  = google_service_account.vm.email
    scopes = ["https://www.googleapis.com/auth/logging.write"]
  }

  scheduling {
    provisioning_model = "SPOT"
    preemptible        = true
    automatic_restart  = false

    # 既定値だが、書かないと apply のたびに STOP -> null の差分が出る。
    # plan が No changes にならないと、他の差分に気づけなくなる。
    instance_termination_action = "STOP"
  }

  metadata = {
    enable-oslogin = "TRUE"
    startup-script = file("${path.module}/startup.sh")
  }

  labels = {
    env        = "test"
    system     = "tf-examples"
    component  = "compute"
    managed_by = "terraform"
    example    = "07-iap-ssh-port-forwarding"
  }

  allow_stopping_for_update = true

  depends_on = [
    google_compute_router_nat.nat,
    google_compute_firewall.allow_iap_ssh,
    google_project_iam_member.iap_tunnel,
    google_project_iam_member.os_login,
  ]
}

resource "google_project_iam_member" "iap_tunnel" {
  project = var.project_id
  role    = "roles/iap.tunnelResourceAccessor"
  member  = var.iap_member

  depends_on = [google_project_service.required]
}

resource "google_project_iam_member" "os_login" {
  project = var.project_id
  role    = "roles/compute.osLogin"
  member  = var.iap_member

  depends_on = [google_project_service.required]
}

resource "google_iap_tunnel_instance_iam_member" "ssh" {
  project  = var.project_id
  zone     = google_compute_instance.vm.zone
  instance = google_compute_instance.vm.name
  role     = "roles/iap.tunnelResourceAccessor"
  member   = var.iap_member
}

# VM にサービスアカウントが付いている場合、接続する側にこのロールが要る。
# 公式: roles/iam.serviceAccountUser -- "All users, if the VM has a service account"
# https://docs.cloud.google.com/compute/docs/oslogin/set-up-oslogin
#
# 無いと OS Login のプロファイルは作られるのに
# "Permission denied (publickey)" で弾かれる。プロジェクトのオーナーは
# この権限を含むため、オーナーで試すと気づけない。
resource "google_service_account_iam_member" "vm_sa_user" {
  service_account_id = google_service_account.vm.name
  role               = "roles/iam.serviceAccountUser"
  member             = var.iap_member
}

# Ops Agent がログを送るために要る。scopes だけでは足りず、これが無いと
# エージェントは active のまま 403 で1件も書けない。自分のエラーログすら
# 送れないので、VM の外からは気づけない。
resource "google_project_iam_member" "vm_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.vm.email}"

  depends_on = [google_project_service.required]
}

# 検証で VM に入るための権限。enable-oslogin = TRUE にしているため、
# メタデータの SSH 公開鍵ではなく OS Login で認証する。
#
# osLogin ではなく osAdminLogin を与えている。この例の確認手順は
# sudo journalctl / sudo systemctl を使うため、非管理者の権限では通らない。
# プロジェクトのオーナーは osAdminLogin を含むので気づきにくい。
resource "google_project_iam_member" "iap_tunnel" {
  project = var.project_id
  role    = "roles/iap.tunnelResourceAccessor"
  member  = var.iap_member

  depends_on = [google_project_service.required]
}

resource "google_project_iam_member" "os_admin_login" {
  project = var.project_id
  role    = "roles/compute.osAdminLogin"
  member  = var.iap_member

  depends_on = [google_project_service.required]
}

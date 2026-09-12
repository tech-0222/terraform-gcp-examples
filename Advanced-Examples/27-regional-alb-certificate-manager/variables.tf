variable "project_id" {
  type        = string
  description = "検証に使う Google Cloud プロジェクト ID"
}

variable "region" {
  type        = string
  description = "リージョン外部 ALB と リージョン証明書を作るリージョン"
  default     = "asia-northeast1"
}

variable "zone" {
  type        = string
  description = "バックエンド VM を置くゾーン"
  default     = "asia-northeast1-a"
}

variable "dns_zone_domain" {
  type        = string
  description = <<-EOT
    Cloud DNS で管理するドメイン（末尾のドットは付けない）。

    親ドメイン側から、このサブドメインを Cloud DNS のネームサーバへ委任して
    おくこと。委任しないと DNS 認証の CNAME が引けず、証明書は PENDING の
    まま進まない。
  EOT
}

variable "regional_hostname" {
  type        = string
  description = "DNS 認証で証明書を発行し、リージョン外部 ALB で配信するホスト名（相対名）"
  default     = "regional"
}

variable "global_hostname" {
  type        = string
  description = "LB 認証で証明書を発行し、グローバル外部 ALB で配信するホスト名（相対名）"
  default     = "global"
}

variable "machine_type" {
  type        = string
  description = "バックエンド VM のマシンタイプ"
  default     = "e2-micro"
}

variable "network_name" {
  type    = string
  default = "tf-adv-cm27-vpc"
}

variable "subnet_cidr" {
  type    = string
  default = "10.27.0.0/24"
}

variable "proxy_subnet_cidr" {
  type        = string
  description = "リージョン ALB の Envoy が使う proxy-only サブネット"
  default     = "10.27.128.0/24"
}

variable "enable_global_lb" {
  type        = bool
  description = <<-EOT
    グローバル外部 ALB と、LB 認証の証明書を作るか。

    LB 認証はグローバル限定で、リージョン外部 ALB では使えない。
    比較のためだけに要るので、リージョン側だけ見たいときは false にする。
  EOT
  default     = true
}

variable "iap_member" {
  description = "IAM member granted IAP tunnel and OS Login (for example, user:you@example.com)."
  type        = string

  validation {
    condition     = can(regex("^(user|serviceAccount|group):.+", var.iap_member))
    error_message = "iap_member must look like user:email, serviceAccount:email, or group:email."
  }
}

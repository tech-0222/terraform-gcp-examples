variable "project_id" {
  type        = string
  description = "検証に使う Google Cloud プロジェクト ID"
}

variable "region" {
  type    = string
  default = "asia-northeast1"
}

variable "zone" {
  type    = string
  default = "asia-northeast1-a"
}

variable "environment" {
  type        = string
  description = "VM・GKE・Cloud Run に付ける environment ラベルの値。ダッシュボードの絞り込みに使う"
  default     = "test"
}

variable "vm_name" {
  type    = string
  default = "tf-adv-dash-vm"
}

variable "vm_machine_type" {
  type    = string
  default = "e2-small"
}

variable "cluster_name" {
  type    = string
  default = "tf-adv-dash"
}

variable "node_machine_type" {
  type    = string
  default = "e2-medium"
}

variable "run_service_name" {
  type    = string
  default = "tf-adv-dash-api"
}

variable "run_image" {
  type        = string
  description = "任意のステータスコードを返せる HTTP サーバ。/status/500 で 500 を返す"
  default     = "docker.io/mccutchen/go-httpbin:2.25.0"
}

variable "authorized_ipv4_cidr" {
  type        = string
  description = "GKE コントロールプレーンに接続できる CIDR。実行元のグローバル IP を /32 で指定する"
  sensitive   = true
}

variable "network_name" {
  type    = string
  default = "tf-adv-dash-vpc"
}

variable "subnet_cidr" {
  type    = string
  default = "10.29.0.0/24"
}

variable "pods_cidr" {
  type    = string
  default = "10.29.16.0/20"
}

variable "services_cidr" {
  type    = string
  default = "10.29.32.0/20"
}

variable "project_id" {
  type        = string
  description = "検証に使う Google Cloud プロジェクト ID"
}

variable "region" {
  type    = string
  default = "asia-northeast1"
}

variable "zone" {
  type        = string
  description = "ゾーンクラスタにする。対になるブログ記事の対象はGMPの構成比較で、ノードは1台で足りる"
  default     = "asia-northeast1-a"
}

variable "cluster_name" {
  type    = string
  default = "tf-adv-managed-prometheus"
}

variable "node_machine_type" {
  type        = string
  description = "ノードのマシンタイプ。node-exporter・Managed Collector・Grafana・data source syncerを同時に乗せるため、e2-standard-2相当の余裕を持たせる"
  default     = "e2-standard-2"
}

variable "node_count" {
  type    = number
  default = 1
}

variable "authorized_ipv4_cidr" {
  type        = string
  description = <<-EOT
    コントロールプレーンに接続できる CIDR。実行元のグローバル IP を /32 で指定する。

    ノードは外部 IP を持たない（enable_private_nodes = true）が、
    コントロールプレーンは公開エンドポイントにしている。踏み台を立てずに
    kubectl を使うため。GMPの構成比較が主題で、ネットワーク構成は主題ではない。
  EOT
  sensitive   = true
}

variable "network_name" {
  type    = string
  default = "tf-adv-managed-prometheus-vpc"
}

variable "subnet_cidr" {
  type    = string
  default = "10.41.0.0/24"
}

variable "pods_cidr" {
  type    = string
  default = "10.41.16.0/20"
}

variable "services_cidr" {
  type    = string
  default = "10.41.32.0/20"
}

variable "use_spot" {
  type        = bool
  description = "Spot VM を使う。検証用途では費用を抑えられる"
  default     = true
}

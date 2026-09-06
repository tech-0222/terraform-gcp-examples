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
  description = "ゾーンクラスタにする。退避の観測にノードは1台で足りる"
  default     = "asia-northeast1-a"
}

variable "cluster_name" {
  type    = string
  default = "tf-adv-evict"
}

variable "node_machine_type" {
  type        = string
  description = <<-EOT
    ノードのマシンタイプ。

    退避を起こすには、Pod が確保できるメモリがノードの容量に近い必要がある。
    大きすぎると、退避させるために大量のメモリを掴む Pod が要る。
    e2-medium（4GB）だと allocatable が 2.8GB しかなく、GMP の収集コンポーネントを
    載せると退避を起こす余地が残らない。e2-standard-2（8GB）にする。
  EOT
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
    kubectl を使うため。退避の観測が主題で、ネットワーク構成は主題ではない。
  EOT
  sensitive   = true
}

variable "network_name" {
  type    = string
  default = "tf-adv-evict-vpc"
}

variable "subnet_cidr" {
  type    = string
  default = "10.28.0.0/24"
}

variable "pods_cidr" {
  type    = string
  default = "10.28.16.0/20"
}

variable "services_cidr" {
  type    = string
  default = "10.28.32.0/20"
}

variable "use_spot" {
  type        = bool
  description = "Spot VM を使う。検証用途では費用を抑えられる"
  default     = true
}

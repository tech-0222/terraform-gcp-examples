variable "project_id" {
  type        = string
  description = "検証に使う Google Cloud プロジェクト ID"
}

variable "region" {
  type    = string
  default = "asia-northeast1"
}

variable "operator_member" {
  type        = string
  description = "検証用 SA を借用して操作する人の IAM メンバー（例: user:you@example.com）。Owner でも SA の借用には Token Creator が要る"
}

variable "console_member" {
  type        = string
  description = "Console の権限差を確かめる専用ユーザー（例: user:iam-lab@example.com）。空なら Console 検証用の付与をしない。普段使いの強い権限を持つユーザーを指定しない"
  default     = ""
}

variable "network_name" {
  type    = string
  default = "tf-adv-iam-vpc"
}

variable "subnet_cidr" {
  type    = string
  default = "10.30.0.0/24"
}

# ---------------------------------------------------------------------------
# 段階的に切り替える付与。terraform apply -var=... で1つずつ変え、操作の成否を見る
# ---------------------------------------------------------------------------

variable "subject_bucket_role" {
  type        = string
  description = "tf-adv-iam-subject にバケット単位で付与する Role。空なら付与しない"
  default     = ""
}

variable "console_bucket_role" {
  type        = string
  description = "console_member にバケット単位で付与する Role。空なら付与しない"
  default     = ""
}

variable "console_project_role" {
  type        = string
  description = "console_member にプロジェクト単位で付与する Role。空なら付与しない（Console でバケット一覧を出すための追加権限の検証に使う）"
  default     = ""
}

variable "subject_compute_role" {
  type        = string
  description = "tf-adv-iam-subject にプロジェクト単位で付与する Compute の Role。none / create_only（compute.instances.create だけのカスタムロール）/ instance_admin（roles/compute.instanceAdmin.v1）"
  default     = "none"

  validation {
    condition     = contains(["none", "create_only", "instance_admin"], var.subject_compute_role)
    error_message = "subject_compute_role は none / create_only / instance_admin のいずれか。"
  }
}

variable "create_only_extra_permissions" {
  type        = list(string)
  description = "create_only ロールに compute.instances.create 以外で足す Permission。エラーに出たものを1つずつ足す"
  default     = []
}

variable "subject_can_act_as_runtime" {
  type        = bool
  description = "tf-adv-iam-subject に、Runtime SA に対する roles/iam.serviceAccountUser を付与するか"
  default     = false
}

variable "terraform_compute_role" {
  type        = string
  description = "tf-adv-iam-terraform にプロジェクト単位で付与する Compute の Role。none / create_only / instance_admin"
  default     = "none"

  validation {
    condition     = contains(["none", "create_only", "instance_admin"], var.terraform_compute_role)
    error_message = "terraform_compute_role は none / create_only / instance_admin のいずれか。"
  }
}

variable "terraform_can_act_as_runtime" {
  type        = bool
  description = "tf-adv-iam-terraform に、Runtime SA に対する roles/iam.serviceAccountUser を付与するか"
  default     = false
}

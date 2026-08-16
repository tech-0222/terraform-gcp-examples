# Parameters（自動生成）

このファイルは [terraform-docs](https://github.com/terraform-docs/terraform-docs) により自動生成されます。手動で編集しないでください。

## Requirements

| Name | Version |
| ---- | ------- |
| terraform | >= 1.10.0, < 2.0.0 |
| google | ~> 7.0 |

## Providers

| Name | Version |
| ---- | ------- |
| google | 7.43.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [google_kms_crypto_key.example](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_crypto_key) | resource |
| [google_kms_key_ring.example](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/kms_key_ring) | resource |
| [google_project_service.kms](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_service) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| project\_id | Google Cloud Project ID. | `string` | n/a | yes |
| crypto\_key\_name | CryptoKey name. | `string` | `"tf-example-key"` | no |
| key\_ring\_name\_prefix | Prefix for the KeyRing name. Project ID is appended to reduce collisions. | `string` | `"tf-example-keyring"` | no |
| location | Cloud KMS location. | `string` | `"global"` | no |
| region | Default region for the provider. | `string` | `"asia-northeast1"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| crypto\_key\_id | Cloud KMS CryptoKey resource ID. |
| crypto\_key\_name | Cloud KMS CryptoKey name. |
| key\_ring\_id | Cloud KMS KeyRing resource ID. |
| key\_ring\_name | Cloud KMS KeyRing name. |
| location | Cloud KMS location. |
| project\_id | Google Cloud Project ID. |
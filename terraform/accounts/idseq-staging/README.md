To destroy these resources, you need to either use the generated local statefile, or reconstruct the local statefile using:

***NOTE: If anything is added, like dynamodb, this list will change!***

```bash
terraform import "module.terraform-aws-tfstate-backend.aws_s3_bucket.default[0]" "tfstate-030998640247"
terraform import "module.terraform-aws-tfstate-backend.aws_s3_bucket_ownership_controls.default[0]" "tfstate-030998640247"
terraform import "module.terraform-aws-tfstate-backend.aws_s3_bucket_policy.default[0]" "tfstate-030998640247"
terraform import "module.terraform-aws-tfstate-backend.aws_s3_bucket_public_access_block.default[0]" "tfstate-030998640247"
terraform import "module.terraform-aws-tfstate-backend.aws_s3_bucket_server_side_encryption_configuration.default[0]" "tfstate-030998640247" 
terraform import "module.terraform-aws-tfstate-backend.aws_s3_bucket_versioning.default[0]" "tfstate-030998640247"
terraform import "module.terraform-aws-tfstate-backend.time_sleep.wait_for_aws_s3_bucket_settings[0]" "30s,30s"
```

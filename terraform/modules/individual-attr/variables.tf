variable "s3_bucket_samples" {
  description = "Name of the samples bucket containing PGI"
  type        = string
}

variable "s3_bucket_public_references" {
  description = "Name of the bucket containing public Taxon data"
  type        = string
}

variable "aws_account_id" {
  description = "AWS Account ID"
  type        = string
}

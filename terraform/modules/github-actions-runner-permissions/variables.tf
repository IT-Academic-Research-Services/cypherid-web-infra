variable "env" {
  type = string
}

variable "account_id" {
  type = string
}

variable "s3_bucket_samples" {
  type = string
}

variable "s3_bucket_workflows" {
  type = string
}

variable "s3_bucket_idseq_bench" {
  type = string
}

variable "s3_bucket_public_references" {
  type = string
}

variable "tags" {
  type = object({ project : string, env : string, service : string, owner : string, managedBy : string })
}

output "db_instance_address" {
  value = aws_rds_cluster.db.endpoint
}

output "db_instance_port" {
  value = aws_rds_cluster.db.port
}

output "db_instance_username" {
  value = aws_rds_cluster.db.master_username
}

output "samples_bucket" {
  value = aws_s3_bucket.samples.bucket
}

output "samples_bucket_v1" {
  value       = aws_s3_bucket.samples_v1.bucket
  description = "The new samples bucket that does not contain the team name."
}

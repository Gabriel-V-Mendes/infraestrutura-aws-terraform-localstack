output "kms_key_id" {
  description = "ID da chave KMS do projeto"
  value       = aws_kms_key.main.key_id
}

output "kms_key_arn" {
  description = "ARN da chave KMS do projeto"
  value       = aws_kms_key.main.arn
}

output "artifacts_bucket_id" {
  description = "Nome/ID do bucket S3 de artefatos e backups"
  value       = aws_s3_bucket.artifacts.id
}

output "artifacts_bucket_arn" {
  description = "ARN do bucket S3 de artefatos e backups"
  value       = aws_s3_bucket.artifacts.arn
}

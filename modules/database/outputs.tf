output "db_instance_id" {
  description = "Identificador da instancia RDS PostgreSQL"
  value       = aws_db_instance.postgres.id
}

output "db_endpoint" {
  description = "Endpoint de conexao (host:port) do RDS PostgreSQL"
  value       = aws_db_instance.postgres.endpoint
}

output "db_address" {
  description = "Hostname da instancia RDS PostgreSQL"
  value       = aws_db_instance.postgres.address
}

output "database_url_secret_arn" {
  description = "ARN do segredo no Secrets Manager contendo a DATABASE_URL para a FastAPI"
  value       = aws_secretsmanager_secret.database_url.arn
}

output "ssm_db_endpoint_parameter" {
  description = "Nome do parametro SSM com o endpoint do banco"
  value       = aws_ssm_parameter.db_endpoint.name
}

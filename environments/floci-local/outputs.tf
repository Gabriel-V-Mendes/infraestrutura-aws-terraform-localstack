output "budget_name" {
  description = "Nome do orcamento mensal configurado no AWS Budgets"
  value       = module.budget_alerts.budget_name
}

output "alerts_sns_topic_arn" {
  description = "ARN do topico SNS de alertas"
  value       = module.budget_alerts.sns_topic_arn
}

output "github_oidc_provider_arn" {
  description = "ARN do provedor OIDC do GitHub Actions"
  value       = module.iam_oidc.oidc_provider_arn
}

output "github_actions_role_arn" {
  description = "ARN da IAM Role assumida via OIDC pelo GitHub Actions (sem chaves estaticas)"
  value       = module.iam_oidc.github_actions_role_arn
}

output "vpc_id" {
  description = "ID da VPC"
  value       = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "IDs das subnets publicas (sem NAT Gateway)"
  value       = module.network.public_subnet_ids
}

output "security_groups" {
  description = "IDs dos Security Groups estritos em 3 camadas (ALB -> APP -> DB)"
  value = {
    alb = module.network.alb_security_group_id
    app = module.network.app_security_group_id
    db  = module.network.db_security_group_id
  }
}

output "artifacts_bucket_name" {
  description = "Nome do bucket S3 criptografado e versionado"
  value       = module.storage.artifacts_bucket_id
}

output "rds_endpoint" {
  description = "Endpoint do RDS PostgreSQL Single-AZ"
  value       = module.database.db_endpoint
}

output "database_url_secret_arn" {
  description = "ARN do segredo no Secrets Manager com a DATABASE_URL da FastAPI"
  value       = module.database.database_url_secret_arn
}

output "alb_dns_name" {
  description = "DNS do Application Load Balancer"
  value       = module.compute.alb_dns_name
}

output "autoscaling_group_name" {
  description = "Nome do Auto Scaling Group (1 instancia EC2)"
  value       = module.compute.autoscaling_group_name
}

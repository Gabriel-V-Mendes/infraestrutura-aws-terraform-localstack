output "alb_dns_name" {
  description = "DNS do Application Load Balancer"
  value       = module.compute.alb_dns_name
}

output "rds_endpoint" {
  description = "Endpoint do RDS PostgreSQL"
  value       = module.database.db_endpoint
}

output "github_actions_role_arn" {
  description = "ARN da Role OIDC do GitHub Actions"
  value       = module.iam_oidc.github_actions_role_arn
}

output "oidc_provider_arn" {
  description = "ARN do provedor OIDC do GitHub Actions na AWS"
  value       = aws_iam_openid_connect_provider.github_actions.arn
}

output "github_actions_role_arn" {
  description = "ARN da IAM Role assumida pelo GitHub Actions via OIDC (sem chaves estaticas)"
  value       = aws_iam_role.github_actions_oidc.arn
}

output "github_actions_role_name" {
  description = "Nome da IAM Role do GitHub Actions"
  value       = aws_iam_role.github_actions_oidc.name
}

output "ec2_instance_profile_name" {
  description = "Nome do Instance Profile anexado as instancias EC2 da API"
  value       = aws_iam_instance_profile.ec2_app.name
}

output "ec2_role_arn" {
  description = "ARN da IAM Role da instancia EC2"
  value       = aws_iam_role.ec2_app.arn
}

output "vpc_id" {
  description = "ID da VPC criada"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "Bloco CIDR da VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs das subnets publicas"
  value       = aws_subnet.public[*].id
}

output "alb_security_group_id" {
  description = "ID do Security Group do ALB"
  value       = aws_security_group.alb.id
}

output "app_security_group_id" {
  description = "ID do Security Group da aplicacao (EC2/ASG)"
  value       = aws_security_group.app.id
}

output "db_security_group_id" {
  description = "ID do Security Group do banco de dados (RDS)"
  value       = aws_security_group.db.id
}

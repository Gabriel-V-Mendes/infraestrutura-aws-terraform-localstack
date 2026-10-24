output "alb_arn" {
  description = "ARN do Application Load Balancer"
  value       = aws_lb.app.arn
}

output "alb_dns_name" {
  description = "DNS publico do Application Load Balancer"
  value       = aws_lb.app.dns_name
}

output "target_group_arn" {
  description = "ARN do Target Group apontando para a porta 8000 (/health/ready)"
  value       = aws_lb_target_group.app.arn
}

output "launch_template_id" {
  description = "ID do Launch Template das instancias EC2"
  value       = aws_launch_template.app.id
}

output "autoscaling_group_name" {
  description = "Nome do Auto Scaling Group"
  value       = aws_autoscaling_group.app.name
}

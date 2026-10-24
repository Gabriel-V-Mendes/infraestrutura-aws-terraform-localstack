output "sns_topic_arn" {
  description = "ARN do topico SNS de alertas de orcamento e infraestrutura"
  value       = aws_sns_topic.alerts.arn
}

output "budget_name" {
  description = "Nome do orcamento mensal configurado no AWS Budgets"
  value       = aws_budgets_budget.monthly_cost.name
}

output "cpu_alarm_arn" {
  description = "ARN do alarme de CPU no CloudWatch"
  value       = aws_cloudwatch_metric_alarm.cpu_high.arn
}

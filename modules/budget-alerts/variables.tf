variable "project_name" {
  description = "Nome do projeto usado como prefixo nos recursos"
  type        = string
}

variable "environment" {
  description = "Nome do ambiente (floci-local, dev, prod)"
  type        = string
}

variable "monthly_budget_usd" {
  description = "Limite mensal de orcamento em USD antes de disparar alertas (FinOps)"
  type        = string
  default     = "15.0"
}

variable "alert_email" {
  description = "E-mail para receber notificacoes de orcamento e alarmes"
  type        = string
  default     = "devops-alerts@example.com"
}

variable "kms_key_id" {
  description = "ARN ou ID da chave KMS para criptografar o topico SNS"
  type        = string
}

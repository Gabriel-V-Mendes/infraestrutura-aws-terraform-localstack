variable "environment" {
  description = "Ambiente (dev, prod)"
  type        = string
}

variable "vpc_id" {
  description = "ID da VPC"
  type        = string
}

variable "private_subnets" {
  description = "Lista de subnets privadas para o banco de dados"
  type        = list(string)
}

variable "ec2_security_group_id" {
  description = "O ID do Security Group do EC2 para permitir acesso"
  type        = string
}
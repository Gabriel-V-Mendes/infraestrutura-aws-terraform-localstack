variable "environment" {
  description = "Ambiente (dev, prod, etc)"
  type        = string
}

variable "vpc_id" {
  description = "ID da VPC criada no modulo de rede"
  type        = string
}

variable "public_subnets" {
  description = "Lista de IDs das subnets publicas"
  type        = list(string)
}

variable "private_subnets" {
  description = "Lista de IDs das subnets privadas"
  type        = list(string)
}

variable "instance_type" {
  description = "Tipo da instancia EC2"
  type        = string
  default     = "t3.micro"
}
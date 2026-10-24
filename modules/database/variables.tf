variable "project_name" {
  description = "Nome do projeto"
  type        = string
}

variable "environment" {
  description = "Ambiente (floci-local, prod)"
  type        = string
}

variable "subnet_ids" {
  description = "Lista de subnets para o DB Subnet Group"
  type        = list(string)
}

variable "db_security_group_id" {
  description = "ID do Security Group restrito do banco de dados"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN da chave KMS para criptografar disco do RDS, Secrets Manager e SSM"
  type        = string
}

variable "instance_class" {
  description = "Classe da instancia RDS (db.t4g.micro para camada economica)"
  type        = string
  default     = "db.t4g.micro"
}

variable "engine_version" {
  description = "Versao do PostgreSQL no RDS (alinhada ao Postgres 17 do Projeto 1)"
  type        = string
  default     = "17.2"
}

variable "allocated_storage" {
  description = "Armazenamento alocado em GiB (gp3)"
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Nome do banco de dados inicial"
  type        = string
  default     = "devops"
}

variable "db_username" {
  description = "Usuario administrador do banco"
  type        = string
  default     = "devops_admin"
}

variable "db_password" {
  description = "Senha do banco de dados (injetada via TF_VAR_db_password, nunca hardcoded)"
  type        = string
  sensitive   = true
}

variable "multi_az" {
  description = "Habilita Multi-AZ (false por padrao para arquitetura economica)"
  type        = bool
  default     = false
}

variable "deletion_protection" {
  description = "Protecao contra delecao acidental (false em testes para permitir destroy completo)"
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Pula snapshot final ao executar destroy nos ambientes de teste"
  type        = bool
  default     = true
}

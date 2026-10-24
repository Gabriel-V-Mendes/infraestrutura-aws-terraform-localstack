variable "project_name" {
  description = "Nome do projeto"
  type        = string
}

variable "environment" {
  description = "Ambiente (floci-local, prod)"
  type        = string
}

variable "force_destroy" {
  description = "Permite destruir o bucket mesmo com objetos durante testes automatizados (destroy do zero)"
  type        = bool
  default     = true
}

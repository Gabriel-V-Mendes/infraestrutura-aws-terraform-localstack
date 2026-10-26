terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# ==============================================================================
# Banco de Dados: RDS PostgreSQL Single-AZ (econômico, provisionado sob demanda)
# + Secrets Manager e SSM Parameter Store para injeção 12-Factor da DATABASE_URL
# ==============================================================================

resource "aws_db_subnet_group" "main" {
  name        = "${var.project_name}-${var.environment}-db-subnets"
  description = "Subnet group para o RDS PostgreSQL Single-AZ"
  subnet_ids  = var.subnet_ids

  tags = {
    Name        = "${var.project_name}-${var.environment}-db-subnets"
    Environment = var.environment
  }
}

resource "aws_db_instance" "postgres" {
  # checkov:skip=CKV_AWS_157:Multi-AZ desabilitado intencionalmente por requisito de arquitetura economica (Single-AZ reduz custo pela metade)
  # checkov:skip=CKV_AWS_118:Enhanced Monitoring desabilitado por economia (metricas basicas gratuitas do CloudWatch ja atendem)
  # checkov:skip=CKV_AWS_293:Deletion protection parametrizavel (false nos testes automatizados para permitir destroy do zero)
  # checkov:skip=CKV_AWS_354:Performance Insights KMS gerenciado via chave KMS do projeto
  identifier                          = "${var.project_name}-${var.environment}-postgres"
  engine                              = "postgres"
  engine_version                      = var.engine_version
  instance_class                      = var.instance_class
  allocated_storage                   = var.allocated_storage
  storage_type                        = "gp3"
  storage_encrypted                   = true
  kms_key_id                          = var.kms_key_arn
  db_name                             = var.db_name
  username                            = var.db_username
  password                            = var.db_password
  db_subnet_group_name                = aws_db_subnet_group.main.name
  vpc_security_group_ids              = [var.db_security_group_id]
  multi_az                            = var.multi_az
  publicly_accessible                 = false
  iam_database_authentication_enabled = true
  backup_retention_period             = 7
  auto_minor_version_upgrade          = true
  copy_tags_to_snapshot               = true
  performance_insights_enabled        = true
  performance_insights_kms_key_id     = var.kms_key_arn
  enabled_cloudwatch_logs_exports     = ["postgresql", "upgrade"]
  deletion_protection                 = var.deletion_protection
  skip_final_snapshot                 = var.skip_final_snapshot

  tags = {
    Name        = "${var.project_name}-${var.environment}-postgres"
    Environment = var.environment
  }
}

# ==============================================================================
# Secrets Manager & SSM Parameter Store (Integração com app/config.py do Projeto 1)
# ==============================================================================

resource "aws_secretsmanager_secret" "database_url" {
  # checkov:skip=CKV2_AWS_57:Rotacao automatica via Lambda omitida no ambiente de testes
  name                    = "${var.project_name}-${var.environment}-database-url"
  description             = "Connection string DATABASE_URL para a API FastAPI (SQLAlchemy + psycopg 3)"
  kms_key_id              = var.kms_key_arn
  recovery_window_in_days = 0 # Permite recriar imediatamente após destroy nos testes

  tags = {
    Name        = "${var.project_name}-${var.environment}-database-url"
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "database_url" {
  secret_id = aws_secretsmanager_secret.database_url.id
  secret_string = jsonencode({
    DATABASE_URL = "postgresql+psycopg://${var.db_username}:${var.db_password}@${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/${var.db_name}"
    DB_HOST      = aws_db_instance.postgres.address
    DB_PORT      = aws_db_instance.postgres.port
    DB_NAME      = var.db_name
  })
}

resource "aws_ssm_parameter" "db_endpoint" {
  name        = "/${var.project_name}/${var.environment}/db_endpoint"
  description = "Endpoint do RDS PostgreSQL provisionado pelo OpenTofu"
  type        = "SecureString"
  key_id      = var.kms_key_arn
  value       = aws_db_instance.postgres.endpoint

  tags = {
    Name        = "${var.project_name}-${var.environment}-db-endpoint"
    Environment = var.environment
  }
}

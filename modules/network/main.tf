terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ==============================================================================
# Arquitetura Econômica de Rede:
# - VPC com 2 Subnets Públicas em AZs distintas (necessário para ALB e RDS Subnet Group)
# - SEM NAT Gateway (economia de ~US$ 32,85/mês fixos + processamento por GB)
# - Isolamento garantido por Security Groups estritos em 3 camadas (ALB -> EC2 -> RDS)
# ==============================================================================

# trivy:ignore:AVD-AWS-0178
resource "aws_vpc" "main" {
  # checkov:skip=CKV2_AWS_11:VPC Flow Logs omitidos por padrao na arquitetura economica (evita custo continuo de ingestao no CloudWatch Logs)
  # checkov:skip=CKV2_AWS_12:Isolamento feito via Security Groups dedicados por camada (alb, app, db)
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-vpc"
    Environment = var.environment
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-${var.environment}-igw"
    Environment = var.environment
  }
}

resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false # IP publico controlado explicitamente apenas no Launch Template da EC2

  tags = {
    Name        = "${var.project_name}-${var.environment}-public-${var.availability_zones[count.index]}"
    Environment = var.environment
    Tier        = "public-economic"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-public-rt"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ==============================================================================
# Camada 1: Security Group do Application Load Balancer (ALB)
# ==============================================================================
# trivy:ignore:AVD-AWS-0107
resource "aws_security_group" "alb" {
  # checkov:skip=CKV_AWS_260:ALB publico precisa aceitar HTTP (porta 80) da internet para receber trafego dos clientes
  name        = "${var.project_name}-${var.environment}-alb-sg"
  description = "Permite entrada HTTP/HTTPS da internet e saida exclusiva para a porta 8000 da API na VPC"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP de entrada para o ALB"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_ingress_cidrs
  }

  ingress {
    description = "HTTPS de entrada para o ALB"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_ingress_cidrs
  }

  egress {
    description = "Encaminha trafego exclusivamente para a porta 8000 das instancias da API na VPC"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-alb-sg"
    Environment = var.environment
  }
}

# ==============================================================================
# Camada 2: Security Group da Aplicação FastAPI (EC2 / Auto Scaling)
# ==============================================================================
# trivy:ignore:AVD-AWS-0104
resource "aws_security_group" "app" {
  # checkov:skip=CKV_AWS_382:Instancia EC2 em subnet publica sem NAT Gateway precisa de saida 443 para baixar a imagem Docker do GHCR
  name        = "${var.project_name}-${var.environment}-app-sg"
  description = "Aceita porta 8000 SOMENTE do ALB; permite saida 5432 para o RDS na VPC e 443 para pull do GHCR"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Permite HTTP na porta 8000 exclusivamente vindo do Security Group do ALB"
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Conexao PostgreSQL (5432) restrita ao CIDR interno da VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "HTTPS (443) para pull da imagem no GHCR e chamadas de API AWS (Secrets Manager/SSM)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-app-sg"
    Environment = var.environment
  }
}

# ==============================================================================
# Camada 3: Security Group do Banco de Dados (RDS PostgreSQL Single-AZ)
# ==============================================================================
resource "aws_security_group" "db" {
  name        = "${var.project_name}-${var.environment}-db-sg"
  description = "Isolamento estrito: aceita conexoes na porta 5432 SOMENTE do Security Group da EC2 da API"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL 5432 permitido apenas a partir das instancias da API FastAPI"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-db-sg"
    Environment = var.environment
  }
}

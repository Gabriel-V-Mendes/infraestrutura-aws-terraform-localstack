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
# Autenticação GitHub Actions na AWS por OIDC (Zero Chaves Estáticas!)
# + Instance Profile de menor privilégio para a instância EC2 da API FastAPI
# ==============================================================================

data "aws_caller_identity" "current" {}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = {
    Name        = "${var.project_name}-${var.environment}-github-oidc"
    Environment = var.environment
  }
}

resource "aws_iam_role" "github_actions_oidc" {
  name        = "${var.project_name}-${var.environment}-gha-oidc-role"
  description = "Role assumida pelo GitHub Actions via OIDC (AssumeRoleWithWebIdentity) sem chaves estaticas"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GitHubActionsOIDCFederation"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repository}:*"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-gha-oidc-role"
    Environment = var.environment
  }
}

# trivy:ignore:AVD-AWS-0057
resource "aws_iam_role_policy" "github_actions_iac" {
  # checkov:skip=CKV_AWS_290:Role dedicada ao pipeline de IaC (OpenTofu) autenticado via OIDC restrito ao repositorio
  # checkov:skip=CKV_AWS_355:Role de provisionamento do OpenTofu precisa criar/descrever recursos no escopo da conta
  name = "${var.project_name}-${var.environment}-gha-iac-policy"
  role = aws_iam_role.github_actions_oidc.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowStateBucketAccess"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.state_bucket_name}",
          "arn:aws:s3:::${var.state_bucket_name}/*"
        ]
      },
      {
        Sid    = "AllowProjectBucketsManagement"
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
          "s3:DeleteBucket",
          "s3:GetBucket*",
          "s3:PutBucket*",
          "s3:PutEncryptionConfiguration",
          "s3:GetEncryptionConfiguration",
          "s3:PutLifecycleConfiguration",
          "s3:GetLifecycleConfiguration",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-*"
        ]
      },
      {
        Sid    = "AllowProjectInfraProvisioning"
        Effect = "Allow"
        Action = [
          "ec2:*",
          "elasticloadbalancing:*",
          "autoscaling:*",
          "rds:*",
          "kms:*",
          "ssm:*",
          "secretsmanager:*",
          "sns:*",
          "cloudwatch:*",
          "budgets:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# ==============================================================================
# Role e Instance Profile para a EC2 da aplicação FastAPI (Menor Privilégio)
# ==============================================================================

resource "aws_iam_role" "ec2_app" {
  name        = "${var.project_name}-${var.environment}-ec2-app-role"
  description = "Role de menor privilegio para a EC2 buscar DATABASE_URL no Secrets Manager e acessar o bucket S3 da aplicacao"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-ec2-app-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "ec2_app_least_privilege" {
  name = "${var.project_name}-${var.environment}-ec2-app-policy"
  role = aws_iam_role.ec2_app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadAppSecretsAndParameters"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = [
          "arn:aws:secretsmanager:*:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}-${var.environment}-*",
          "arn:aws:ssm:*:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/${var.environment}/*"
        ]
      },
      {
        Sid    = "AccessAppArtifactsBucket"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.app_bucket_arn,
          "${var.app_bucket_arn}/*"
        ]
      },
      {
        Sid    = "UseProjectKmsKey"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = [
          var.kms_key_arn
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_app" {
  name = "${var.project_name}-${var.environment}-ec2-app-profile"
  role = aws_iam_role.ec2_app.name
}

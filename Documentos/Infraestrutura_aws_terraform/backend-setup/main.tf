# 1. Bucket S3 para guardar o state file de forma segura
resource "aws_s3_bucket" "terraform_state" {
  bucket = "infraestrutura-aws-terraform-state"
}

# Habilitar versionamento para não perder o histórico caso eu delete algo
resource "aws_s3_bucket_versioning" "state_versioning" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Criptografar o bucket por padrão
resource "aws_s3_bucket_server_side_encryption_configuration" "state_encryption" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 2. Tabela do DynamoDB para o State Locking
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "infraestrutura-aws-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

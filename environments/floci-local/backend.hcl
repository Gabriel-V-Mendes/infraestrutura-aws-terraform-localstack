# Backend S3 emulado no Floci com Lock Nativo do OpenTofu 1.10+ (use_lockfile = true)
# Substitui a necessidade de tabela DynamoDB dedicada para lock de state!
bucket                      = "devops-api-tofu-state"
key                         = "floci-local/terraform.tfstate"
region                      = "us-east-1"
endpoint                    = "http://localhost:4566"
use_path_style              = true
use_lockfile                = true
skip_credentials_validation = true
skip_region_validation      = true
skip_metadata_api_check     = true
skip_requesting_account_id  = true

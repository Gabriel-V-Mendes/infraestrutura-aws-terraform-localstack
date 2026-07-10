terraform {
  backend "s3" {
    bucket                      = "infraestrutura-aws-terraform-state"
    key                         = "dev/terraform.tfstate"
    region                      = "us-east-1"
    
    access_key                  = "test"
    secret_key                  = "test"
    
    endpoints = {
      s3 = "http://localhost:4566"
    }

    
    use_lockfile                = true
    encrypt                     = true
    
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true
  }
}
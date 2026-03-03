terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# S3 Bucket for Terraform State
resource "aws_s3_bucket" "terraform_state" {
  bucket              = "${var.state_bucket_name}-${data.aws_caller_identity.current.account_id}"
  force_destroy       = var.force_destroy_bucket

  tags = merge(
    var.tags,
    { Name = "${var.state_bucket_name}-terraform-state" }
  )
}

# Enable Versioning on S3 Bucket (protects against accidental deletions)
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable Server-Side Encryption on S3 Bucket (security best practice)
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block Public Access on S3 Bucket (security best practice)
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable Lifecycle Rule (transition old versions to cheaper storage)
resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "delete-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 90  # Delete versions older than 90 days
    }
  }
}

# DynamoDB Table for State Locking
resource "aws_dynamodb_table" "terraform_locks" {
  name           = "${var.lock_table_name}-terraform-locks"
  billing_mode   = "PAY_PER_REQUEST"  # On-demand billing (cost-effective)
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true  # Enable PITR for disaster recovery
  }

  tags = merge(
    var.tags,
    { Name = "${var.lock_table_name}-terraform-locks" }
  )
}

# Get current AWS account ID (for unique S3 bucket naming)
data "aws_caller_identity" "current" {}

# Get current AWS region from provider
data "aws_region" "current" {}

# Outputs for backend configuration
output "s3_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for state locking"
  value       = aws_dynamodb_table.terraform_locks.name
}

output "aws_region" {
  description = "AWS region"
  value       = data.aws_region.current.name
}

output "encrypt" {
  description = "Encryption enabled"
  value       = "true"
}

output "backend_config_command" {
  description = "Command to initialize backend"
  value       = "terraform init -backend-config='bucket=${aws_s3_bucket.terraform_state.id}' -backend-config='dynamodb_table=${aws_dynamodb_table.terraform_locks.name}' -backend-config='region=${data.aws_region.current.name}' -backend-config='encrypt=true'"
}

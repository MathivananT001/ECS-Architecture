variable "aws_region" {
  description = "AWS region for backend resources"
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_name" {
  description = "Name prefix for the S3 bucket storing Terraform state"
  type        = string
  default     = "terraform-state"
}

variable "lock_table_name" {
  description = "Name prefix for the DynamoDB table for state locking"
  type        = string
  default     = "terraform"
}

variable "force_destroy_bucket" {
  description = "Allow destruction of S3 bucket even if it contains objects (use with caution!)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project     = "serverless-architecture"
    Component   = "terraform-backend"
    Managed     = "terraform"
    Environment = "production"
  }
}

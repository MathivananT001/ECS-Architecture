# Backend configuration values
aws_region            = "us-east-1"
state_bucket_name     = "terraform-state-serverless-app"
lock_table_name       = "terraform-serverless-app"
force_destroy_bucket  = false

tags = {
  Project     = "serverless-architecture"
  Component   = "terraform-backend"
  Managed     = "terraform"
  Environment = "production"
}

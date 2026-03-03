# Backend Configuration for Remote State with S3 + DynamoDB
# This file is used during 'terraform init' to configure the remote backend
# See backend/main.tf for the resources that need to be created first

terraform {
  backend "s3" {
    # These values should be populated during terraform init
    # Example: terraform init -backend-config="bucket=..." -backend-config="dynamodb_table=..."
    # OR use environment variables: TF_BACKEND_BUCKET, TF_BACKEND_DYNAMODB_TABLE
    
    key            = "serverless-app/terraform.tfstate"  # Path within bucket
    region         = "us-east-1"                         # Must match backend region
    encrypt        = true                                # Enable encryption
    skip_region_validation = false                       # Validate region
  }
}

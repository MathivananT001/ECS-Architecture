aws_region            = "us-east-1"
app_name              = "serverless-app"
environment           = "production"
availability_zone     = "us-east-1a"
container_port        = 8080
# Update this with your ECR image URL after pushing
# Format: <account-id>.dkr.ecr.<region>.amazonaws.com/<repo-name>:<tag>
container_image       = "<YOUR_ECR_IMAGE_URL>"
task_cpu              = 256
task_memory           = 512
desired_count         = 2

tags = {
  Project     = "serverless-architecture"
  Managed     = "terraform"
  Environment = "production"
}

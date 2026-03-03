#!/bin/bash
# Deployment script for Serverless ECS Fargate Architecture
# This script automates the entire deployment process

set -e  # Exit on error

echo "=========================================="
echo "Serverless ECS Fargate Deployment Script"
echo "=========================================="
echo ""

# Check prerequisites
echo "Checking prerequisites..."
command -v terraform >/dev/null 2>&1 || { echo "Terraform not found. Please install Terraform."; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "Docker not found. Please install Docker."; exit 1; }
command -v aws >/dev/null 2>&1 || { echo "AWS CLI not found. Please install AWS CLI."; exit 1; }

# Get AWS region from terraform.tfvars
AWS_REGION=$(grep "^aws_region" terraform.tfvars | cut -d'"' -f2)
echo "✓ AWS Region: $AWS_REGION"

# Step 1: Build Docker image
echo ""
echo "Step 1/7: Building Docker image..."
cd app
docker build -t serverless-app:latest .
cd ..
echo "✓ Docker image built"

# Step 2: Initialize Terraform
echo ""
echo "Step 2/7: Initializing Terraform..."
terraform init
echo "✓ Terraform initialized"

# Step 3: Plan infrastructure
echo ""
echo "Step 3/7: Planning infrastructure..."
terraform plan -out=tfplan
echo "✓ Infrastructure plan created"

# Step 4: Apply infrastructure (creates ECR)
echo ""
echo "Step 4/7: Creating infrastructure (ECR)..."
terraform apply tfplan
echo "✓ Infrastructure created"

# Step 5: Get ECR repository URL
echo ""
echo "Step 5/7: Pushing Docker image to ECR..."
ECR_URL=$(terraform output -raw ecr_repository_url)
echo "ECR Repository URL: $ECR_URL"

# Login to ECR
echo "Logging in to ECR..."
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $ECR_URL

# Tag and push image
echo "Pushing image to ECR..."
docker tag serverless-app:latest $ECR_URL:latest
docker push $ECR_URL:latest
echo "✓ Image pushed to ECR"

# Step 6: Update terraform.tfvars
echo ""
echo "Step 6/7: Updating terraform.tfvars..."
sed -i "s|container_image.*=.*|container_image = \"$ECR_URL:latest\"|" terraform.tfvars
echo "✓ terraform.tfvars updated"

# Step 7: Deploy ECS service
echo ""
echo "Step 7/7: Deploying ECS service..."
terraform plan -out=tfplan
terraform apply tfplan
echo "✓ ECS service deployed"

# Get application URL
echo ""
echo "=========================================="
echo "✅ Deployment Complete!"
echo "=========================================="
ALB_DNS=$(terraform output -raw alb_dns_name)
echo ""
echo "Application URL: http://$ALB_DNS"
echo ""
echo "Next steps:"
echo "1. Open http://$ALB_DNS in your browser"
echo "2. View logs: aws logs tail /ecs/serverless-app --follow --region $AWS_REGION"
echo "3. Check status: terraform output"
echo ""
echo "To destroy: terraform destroy"
echo "=========================================="

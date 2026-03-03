# Deployment script for Serverless ECS Fargate Architecture (Windows PowerShell)
# This script automates the entire deployment process

param(
    [switch]$SkipImageBuild = $false,
    [switch]$SkipValidation = $false
)

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Serverless ECS Fargate Deployment Script" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Check prerequisites
if (-not $SkipValidation) {
    Write-Host "Checking prerequisites..." -ForegroundColor Yellow
    
    $tools = @("terraform", "docker", "aws")
    foreach ($tool in $tools) {
        if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
            Write-Host "✗ $tool not found. Please install $tool first." -ForegroundColor Red
            exit 1
        }
        Write-Host "✓ $tool found" -ForegroundColor Green
    }
}

# Get AWS region from terraform.tfvars
$awsRegion = (Select-String -Path terraform.tfvars -Pattern '^aws_region\s*=' | `
    Select-Object -First 1 | ForEach-Object { $_ -replace '.*"([^"]+)".*', '$1' })

if ([string]::IsNullOrEmpty($awsRegion)) {
    $awsRegion = "us-east-1"
}

Write-Host "AWS Region: $awsRegion" -ForegroundColor Green
Write-Host ""

# Step 1: Build Docker image
if (-not $SkipImageBuild) {
    Write-Host "Step 1/7: Building Docker image..." -ForegroundColor Yellow
    Push-Location app
    docker build -t serverless-app:latest .
    if ($LASTEXITCODE -ne 0) {
        Write-Host "✗ Docker build failed" -ForegroundColor Red
        exit 1
    }
    Pop-Location
    Write-Host "✓ Docker image built" -ForegroundColor Green
} else {
    Write-Host "Step 1/7: Skipping Docker image build (--SkipImageBuild)" -ForegroundColor Yellow
}

Write-Host ""

# Step 2: Initialize Terraform
Write-Host "Step 2/7: Initializing Terraform..." -ForegroundColor Yellow
terraform init
if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Terraform init failed" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Terraform initialized" -ForegroundColor Green

Write-Host ""

# Step 3: Validate Terraform
Write-Host "Step 3/7: Validating Terraform configuration..." -ForegroundColor Yellow
terraform validate
if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Terraform validation failed" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Terraform configuration is valid" -ForegroundColor Green

Write-Host ""

# Step 4: Plan infrastructure
Write-Host "Step 4/7: Planning infrastructure..." -ForegroundColor Yellow
terraform plan -out=tfplan
if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Terraform plan failed" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Infrastructure plan created" -ForegroundColor Green

Write-Host ""

# Step 5: Apply infrastructure
Write-Host "Step 5/7: Creating infrastructure..." -ForegroundColor Yellow
Write-Host "This may take 5-10 minutes..." -ForegroundColor Yellow
terraform apply tfplan
if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Terraform apply failed" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Infrastructure created" -ForegroundColor Green

Write-Host ""

# Step 6: Push image to ECR
Write-Host "Step 6/7: Pushing Docker image to ECR..." -ForegroundColor Yellow

$ecrUrl = terraform output -raw ecr_repository_url

Write-Host "ECR Repository URL: $ecrUrl" -ForegroundColor Cyan

# Login to ECR
Write-Host "Logging in to ECR..." -ForegroundColor Yellow
$loginCmd = "aws ecr get-login-password --region $awsRegion | docker login --username AWS --password-stdin $ecrUrl"
Invoke-Expression $loginCmd
if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ ECR login failed" -ForegroundColor Red
    exit 1
}

# Tag and push image
Write-Host "Tagging and pushing image to ECR..." -ForegroundColor Yellow
docker tag serverless-app:latest "$($ecrUrl):latest"
docker push "$($ecrUrl):latest"
if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Docker push failed" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Image pushed to ECR" -ForegroundColor Green

Write-Host ""

# Step 7: Update Terraform and deploy
Write-Host "Step 7/7: Updating configuration and deploying ECS service..." -ForegroundColor Yellow

# Read terraform.tfvars
$tfvarsContent = Get-Content terraform.tfvars -Raw

# Replace container_image
$tfvarsContent = $tfvarsContent -replace 'container_image\s*=\s*"[^"]*"', "container_image       = `"$ecrUrl`:latest`""

# Write back
Set-Content terraform.tfvars $tfvarsContent

Write-Host "✓ terraform.tfvars updated with ECR image URL" -ForegroundColor Green

# Final plan and apply
terraform plan -out=tfplan
terraform apply tfplan
if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ ECS deployment failed" -ForegroundColor Red
    exit 1
}
Write-Host "✓ ECS service deployed" -ForegroundColor Green

Write-Host ""

# Get application URL
$albDns = terraform output -raw alb_dns_name
$ecsCluster = terraform output -raw ecs_cluster_name
$ecsService = terraform output -raw ecs_service_name
$logGroup = terraform output -raw cloudwatch_log_group

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "✅ Deployment Complete!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "📍 Application URL: http://$albDns" -ForegroundColor Cyan
Write-Host ""
Write-Host "📊 ECS Cluster: $ecsCluster" -ForegroundColor Cyan
Write-Host "📊 ECS Service: $ecsService" -ForegroundColor Cyan
Write-Host "📊 Logs: $logGroup" -ForegroundColor Cyan
Write-Host ""
Write-Host "🔗 View logs:" -ForegroundColor Yellow
Write-Host "   aws logs tail $logGroup --follow --region $awsRegion" -ForegroundColor Gray
Write-Host ""
Write-Host "🔗 Check status:" -ForegroundColor Yellow
Write-Host "   terraform output" -ForegroundColor Gray
Write-Host ""
Write-Host "🔗 Destroy infrastructure:" -ForegroundColor Yellow
Write-Host "   terraform destroy" -ForegroundColor Gray
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan

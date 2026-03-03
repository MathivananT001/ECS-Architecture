# Quick Start Guide - Modular Serverless Architecture

## What Was Created

A complete **modular, production-ready** serverless infrastructure on AWS using:

| Component | Details |
|-----------|---------|
| **Architecture** | ECS Fargate, single AZ, modular Terraform |
| **Application** | Simple Node.js Express app (Hello World) |
| **Container Registry** | AWS ECR for image management |
| **Load Balancing** | Application Load Balancer with HTTPS redirect |
| **Networking** | VPC, public/private subnets, security groups |
| **Auto-Scaling** | CPU/Memory-based (2-4 tasks) |
| **Logging** | CloudWatch (7-day retention) |

## Directory Structure

```
root/
├── modules/
│   ├── vpc/              ← VPC, subnets, routes
│   ├── security/         ← Security groups
│   ├── iam/              ← IAM roles
│   ├── alb/              ← Load balancer
│   ├── ecs/              ← ECS cluster, tasks, service
│   └── ecr/              ← ECR repository
├── app/                  ← Node.js application
│   ├── server.js         ← Express server
│   ├── package.json      ← Dependencies
│   ├── Dockerfile        ← Docker image
│   └── README.md         ← App docs
├── main.tf               ← Root module (calls all modules)
├── variables.tf          ← Root variables
├── terraform.tfvars      ← Configuration
└── outputs.tf            ← Root outputs
```

## Deployment Workflow (7 Steps)

### Step 1: Build Node.js Docker Image

```bash
cd app
docker build -t serverless-app:latest .
```

Test locally (optional):
```bash
docker run -p 8080:8080 serverless-app:latest
# Visit http://localhost:8080
```

### Step 2: Initialize Terraform

```bash
cd ..
terraform init
```

Creates `.terraform/` and prepares providers.

### Step 3: Preview Infrastructure

```bash
terraform plan
```

Shows all resources that will be created.

### Step 4: Create ECR Repository & Push Image

```bash
# Get ECR URL from infrastructure output
ECR_URL=$(terraform output -raw ecr_repository_url)
echo "ECR URL: $ECR_URL"

# Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin $ECR_URL

# Tag and push image
docker tag serverless-app:latest $ECR_URL:latest
docker push $ECR_URL:latest
```

### Step 5: Update terraform.tfvars

Edit `terraform.tfvars` and update:

```hcl
container_image = "<YOUR_ECR_URL>:latest"
```

Example:
```hcl
container_image = "123456789.dkr.ecr.us-east-1.amazonaws.com/serverless-app:latest"
```

### Step 6: Deploy Infrastructure

```bash
terraform plan -out=tfplan
terraform apply tfplan
```

### Step 7: Access Application

```bash
ALB_DNS=$(terraform output -raw alb_dns_name)
echo "Application: http://$ALB_DNS"

# Open in browser
open "http://$ALB_DNS"  # macOS
start "http://$ALB_DNS"  # Windows
xdg-open "http://$ALB_DNS"  # Linux
```

## Module Architecture

### 1. **VPC Module** (`modules/vpc/`)
- VPC with Internet Gateway
- Public subnet (for ALB)
- Private subnet (for ECS tasks)
- Route tables

### 2. **Security Module** (`modules/security/`)
- ALB security group (80, 443)
- ECS security group (8080 from ALB)

### 3. **IAM Module** (`modules/iam/`)
- Task Execution Role (ECR, CloudWatch)
- Task Role (app permissions)

### 4. **ALB Module** (`modules/alb/`)
- Application Load Balancer
- HTTP & HTTPS listeners
- Self-signed certificate

### 5. **ECR Module** (`modules/ecr/`)
- Container image repository
- Lifecycle policy (keeps last 5 images)

### 6. **ECS Module** (`modules/ecs/`)
- Fargate cluster & service
- Task definition (pulls from ECR)
- Auto-scaling & logging

## Node.js Application

Located in `app/`:

- **server.js** - Express HTTP server
  - `GET /` → HTML page "Hello World"
  - `GET /health` → Health check `{ "status": "healthy" }`

- **Dockerfile** - Multi-stage build
  - Size optimized (~150MB)
  - Node 18 Alpine base

## Common Operations

### View Application Logs

```bash
# Real-time logs
aws logs tail /ecs/serverless-app --follow

# Or via Terraform
LOG_GROUP=$(terraform output -raw cloudwatch_log_group)
aws logs tail $LOG_GROUP --follow
```

### Scale Application

Edit `terraform.tfvars`:
```hcl
desired_count = 4  # Auto-scales 4-4
```

Apply:
```bash
terraform apply
```

### Update Application

1. Edit `app/server.js`
2. Build: `docker build -t serverless-app:v2 .`
3. Push: `docker push $ECR_URL:v2`
4. Update `terraform.tfvars`: `container_image = "$ECR_URL:v2"`
5. Apply: `terraform apply`

### View Outputs

```bash
terraform output

# Or specific
terraform output alb_dns_name
terraform output ecr_repository_url
terraform output ecs_cluster_name
```

### Check ECS Status

```bash
CLUSTER=$(terraform output -raw ecs_cluster_name)
SERVICE=$(terraform output -raw ecs_service_name)

aws ecs describe-services \
  --cluster $CLUSTER \
  --services $SERVICE \
  --region us-east-1

aws ecs list-tasks \
  --cluster $CLUSTER \
  --service-name $SERVICE
```

### Destroy Everything

```bash
terraform destroy
```

## Key Variables in terraform.tfvars

```hcl
# AWS Region
aws_region = "us-east-1"

# Application
app_name = "serverless-app"
container_image = "<YOUR_ECR_URL>:latest"

# Networking
vpc_cidr = "10.0.0.0/16"
public_subnet_cidr = "10.0.1.0/24"
private_subnet_cidr = "10.0.2.0/24"
availability_zone = "us-east-1a"

# Container
container_port = 8080
task_cpu = 256
task_memory = 512
desired_count = 2
```

## Pricing Estimate

Approximate monthly costs (US East 1):

```
ALB                    $16.00
ECS Fargate (2×256CPU, 512MB) $31.00
ECR Repositories       $0.10
CloudWatch Logs        $0.50
────────────────────────────
Total          ~$47.60
```

## Troubleshooting

**"No target healthy"**
- Check ALB target group health
- Verify security group allows ALB → ECS port 8080
- Check CloudWatch logs

**"Image not found in ECR"**
- Verify `container_image` is correct
- Confirm image was pushed: `aws ecr list-images --repository-name serverless-app`

**"Terraform apply fails"**
- Run `terraform validate`
- Check AWS credentials: `aws sts get-caller-identity`

## Destroying Everything

```bash
terraform destroy
```

---

**Status:** ✅ Ready to Deploy!

**Setup Time:** ~15 minutes (including Docker push)

**Last Updated:** February 2026

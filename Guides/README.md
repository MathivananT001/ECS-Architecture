# Serverless Web Architecture with ECS Fargate (Modular)

A minimal, production-ready AWS serverless architecture using **ECS Fargate** with **Application Load Balancer** and **ECR** for container image management.

## Architecture Overview

```
┌────────────────────────────────────────────────────┐
│           Internet (HTTP/HTTPS)                   │
└──────────────────┬─────────────────────────────────┘
                   │
        ┌──────────▼──────────┐
        │  ALB (Public Subnet)│
        │  - Port 80 (HTTP)   │
        │  - Port 443 (HTTPS) │
        │    → Redirects to 80│
        └──────────┬──────────┘
                   │
        ┌──────────▼──────────────┐         ┌──────────────┐
        │ Target Group            │         │ ECR Registry │
        │ Port 8080               │         │              │
        └──────────┬──────────────┘         └──────────────┘
                   │                              ▲
   ┌───────────────┼───────────────┐            │
   │               │               │            │
┌──▼──┐        ┌──▼──┐        ┌──▼──┐   Pulls Images
│Task │        │Task │        │Task │
│Node.│        │Node.│        │Node.│
│8080 │        │8080 │        │8080 │
└─────┘        └─────┘        └──────┘
(Private Subnet - FARGATE)
```

## Features

✅ **Modular Architecture** - Organized into separate modules  
✅ **Single Availability Zone** - Minimal configuration, lower costs  
✅ **Serverless Fargate** - No EC2 instances to manage  
✅ **ECR Integration** - Push images directly from your app  
✅ **Node.js Application** - Simple "Hello World" Express app included  
✅ **Auto Scaling** - CPU and Memory-based scaling (min: 2, max: 4)  
✅ **HTTP/HTTPS Redirect** - HTTPS requests redirect to HTTP  
✅ **CloudWatch Logging** - Automatic container logging  
✅ **Security Groups** - Isolated network access  
✅ **IAM Roles** - Proper permissions for task execution  

## Project Structure

```
.
├── modules/                          # Terraform modules
│   ├── vpc/                         # VPC, subnets, routes
│   ├── security/                    # Security groups
│   ├── iam/                         # IAM roles & policies
│   ├── alb/                         # Load balancer
│   ├── ecs/                         # ECS cluster, tasks, service
│   └── ecr/                         # ECR repository
│
├── app/                             # Node.js application
│   ├── server.js                   # Express server
│   ├── package.json                # Dependencies
│   ├── Dockerfile                  # Docker image
│   └── README.md                   # App documentation
│
├── main.tf                          # Root module orchestration
├── variables.tf                     # Root variables
├── terraform.tfvars                 # Configuration values
├── outputs.tf                       # Output values
├── README.md                        # This file
├── QUICKSTART.md                    # Quick start guide
└── .gitignore                       # Git ignore rules
```

## Modules Breakdown

### 1. **VPC Module** (`modules/vpc/`)
- Creates VPC with CIDR block
- Public subnet for ALB
- Private subnet for ECS tasks
- Internet Gateway
- Route tables and associations

### 2. **Security Module** (`modules/security/`)
- ALB security group (HTTP/HTTPS ingress)
- ECS security group (restricted to ALB)
- Proper ingress/egress rules

### 3. **IAM Module** (`modules/iam/`)
- ECS task execution role (ECR access, CloudWatch logs)
- ECS task role (application-level permissions)
- Policies for logging and ECR access

### 4. **ALB Module** (`modules/alb/`)
- Application Load Balancer
- Target group for ECS tasks
- HTTP listener (port 80)
- HTTPS listener with redirect (port 443 → 80)
- Self-signed certificate

### 5. **ECS Module** (`modules/ecs/`)
- ECS cluster
- Task definition (pulls from ECR)
- ECS service with load balancer integration
- CloudWatch log group
- Auto-scaling policies (CPU & Memory)

### 6. **ECR Module** (`modules/ecr/`)
- ECR repository
- Lifecycle policy (keeps last 5 images)
- Outputs repository URL for pushing images

## Prerequisites

- AWS Account with appropriate permissions
- Terraform >= 1.0
- AWS CLI configured
- Docker (for building and pushing images)

## Quick Start

### Step 1: Build & Push Docker Image

```bash
# Navigate to app directory
cd app

# Build Docker image
docker build -t serverless-app:latest .

# Initialize Terraform first to get ECR URL
cd ..
terraform init

# Get ECR repository URL
ECR_URL=$(terraform output -raw ecr_repository_url)

# Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin $ECR_URL

# Tag image
docker tag serverless-app:latest $ECR_URL:latest

# Push to ECR
docker push $ECR_URL:latest
```

### Step 2: Update terraform.tfvars

Edit `terraform.tfvars` and update:
```hcl
container_image = "<your-ecr-url>:latest"
```

### Step 3: Deploy Infrastructure

```bash
terraform plan -out=tfplan
terraform apply tfplan
```

### Step 4: Access Application

```bash
ALB_DNS=$(terraform output -raw alb_dns_name)
echo "Visit: http://$ALB_DNS"
```

## Configuration Variables

All variables are defined in `variables.tf` with sensible defaults. Key variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `aws_region` | `us-east-1` | AWS region |
| `app_name` | `serverless-app` | App name |
| `container_image` | Required | Docker image URI from ECR |
| `container_port` | `8080` | Container listening port |
| `task_cpu` | `256` | Fargate CPU units |
| `task_memory` | `512` | Fargate memory (MB) |
| `desired_count` | `2` | Initial task count |
| `vpc_cidr` | `10.0.0.0/16` | VPC CIDR |
| `availability_zone` | `us-east-1a` | Single AZ |

## Deployment Workflow

```
┌─────────────────┐
│ Build App Image │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────┐
│ Push to ECR                 │
└────────┬────────────────────┘
         │
         ▼
┌─────────────────────────────┐
│ Update terraform.tfvars     │
│ with ECR image URL          │
└────────┬────────────────────┘
         │
         ▼
┌─────────────────────────────┐
│ terraform init              │
│ terraform plan              │
│ terraform apply             │
└────────┬────────────────────┘
         │
         ▼
┌─────────────────────────────┐
│ Infrastructure Running      │
│ - VPC, Subnets             │
│ - ALB, Target Groups       │
│ - ECS Cluster, Service     │
│ - Tasks Pulling from ECR   │
└─────────────────────────────┘
```

## Application Details

The included Node.js application (`app/server.js`):

- **Endpoint:** `GET /`
  - Returns HTML page with "Hello World" message
  - Displays service info (port, hostname, time)

- **Health Check:** `GET /health`
  - Returns JSON: `{ "status": "healthy" }`
  - Used by ALB for target health checks

- **Framework:** Express.js
- **Port:** 8080 (inside container)
- **Docker:** Multi-stage build for minimal size

## Outputs After Deployment

```bash
terraform output
```

Returns:
- `alb_dns_name` - Load balancer DNS (use to access app)
- `ecs_cluster_name` - ECS cluster name
- `ecs_service_name` - ECS service name
- `ecr_repository_url` - ECR repo for pushing images
- `cloudwatch_log_group` - Log group name
- `vpc_id`, `public_subnet_id`, `private_subnet_id` - Network IDs

## Viewing Logs

```bash
# Tail logs in real-time
aws logs tail /ecs/serverless-app --follow --region us-east-1

# View specific task logs
ECS_CLUSTER=$(terraform output -raw ecs_cluster_name)
ECS_SERVICE=$(terraform output -raw ecs_service_name)

# Get task ARN
TASK_ARN=$(aws ecs list-tasks \
  --cluster $ECS_CLUSTER \
  --service-name $ECS_SERVICE \
  --query 'taskArns[0]' \
  --output text)
```

## Common Operations

### Update Application

1. Build and push new image to ECR
2. Update `terraform.tfvars` with new image tag
3. `terraform apply` (Terraform handles rolling update)

### Scale Up/Down

Edit `terraform.tfvars`:
```hcl
desired_count = 4  # Auto-scales between this and 4
```

### Change Resources

Edit `terraform.tfvars`:
```hcl
task_cpu    = 512
task_memory = 1024
```

### Destroy Everything

```bash
terraform destroy
```

## Architecture Components

| Component | Type | Details |
|-----------|------|---------|
| VPC | Network | Single AZ, 10.0.0.0/16 CIDR |
| Public Subnet | Network | 10.0.1.0/24, IGW route |
| Private Subnet | Network | 10.0.2.0/24, isolated |
| ALB | Load Balancer | Application Load Balancer |
| Target Group | Routing | HTTP port 8080 |
| Security Groups | Network | ALB (80,443), ECS (8080) |
| ECR | Registry | Container image storage |
| ECS Cluster | Compute | Fargate launch type |
| Task Definition | Compute | 256 CPU, 512 MB mem |
| ECS Service | Compute | 2-4 tasks, auto-scaling |
| CloudWatch | Logging | 7-day retention |

## Pricing Estimate (US East 1)

- **ALB**: ~$16/month + data transfer
- **ECS Fargate**: 256 CPU + 512 MB × 2 tasks ≈ $30/month
- **ECR**: ~$0.10/GB/month (minimal)
- **CloudWatch**: ~$0.50/month
- **Total**: ~$50-100/month

## Limitations & Single AZ Design

❌ Not HA across AZ failures (single AZ)  
❌ No NAT Gateway (private subnet isolated)  
✅ Lower costs  
✅ Faster deployment  
✅ Perfect for dev/test  

**To make HA:** Add another AZ's subnet and update ASG target

## Best Practices Applied

✅ Modular Terraform code  
✅ Separation of concerns  
✅ Reusable modules  
✅ No secrets in code  
✅ Proper IAM permissions  
✅ Health checks configured  
✅ Auto-scaling enabled  
✅ Logging configured  

## Troubleshooting

### Tasks not reaching healthy state
- Check security groups allow ALB → ECS (port 8080)
- Verify ECR image URI is correct
- Check CloudWatch logs: `terraform output cloudwatch_log_group`

### Application not accessible
- Confirm ALB DNS is resolvable
- Check target group health status
- Verify ALB security group allows port 80

### Docker image issues
- Ensure image is pushed to ECR
- Verify image tag in `terraform.tfvars` matches
- Check AWS CLI is configured correctly

## Support

For detailed configuration, see individual module README files:
- [VPC Module](modules/vpc/)
- [Security Module](modules/security/)
- [ECS Module](modules/ecs/)
- [Application Documentation](app/README.md)

---

**Created:** February 2026  
**Terraform Version:** >= 1.0  
**AWS Provider:** ~> 5.0

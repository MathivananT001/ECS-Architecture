# Modular Serverless Architecture - Complete Guide

## Overview

This is a **production-ready, modular** serverless architecture on AWS using:

- **ECS Fargate** for containerized workloads (no EC2 management)
- **Application Load Balancer** for traffic distribution
- **ECR** for container image management
- **CloudWatch** for logging and monitoring
- **Auto Scaling** for dynamic resource allocation

## Architecture Diagram

```
                           Internet
                             ▲
                             │ HTTP/HTTPS
                             │
                    ┌────────▼────────┐
                    │      ALB        │
                    │  ┌─────┬─────┐  │
                    │  │ 80  │ 443 │  │
                    │  └─────┴─────┘  │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │ Target Group    │
                    │ (Port 8080)     │
                    └────────┬────────┘
                             │
                ┌────────────┼────────────┐
                │            │            │
         ┌──────▼────┐ ┌──────▼────┐ ┌──────▼────┐
         │ ECS Task  │ │ ECS Task  │ │ ECS Task  │
         │ (Node.js) │ │ (Node.js) │ │ (Node.js) │
         └───────────┘ └───────────┘ └───────────┘
         
         All pulling from ECR Repository
```

## Modular Structure

Each module is independent and reusable:

### 1. VPC Module (`modules/vpc/`)
**Responsibility:** Networking infrastructure

**Resources:**
- VPC with IPv4 CIDR block
- Internet Gateway for public internet access
- Public subnet (for ALB)
- Private subnet (for ECS tasks)
- Route tables for public and private subnets

**Inputs:** `app_name`, `vpc_cidr`, subnet CIDRs, `availability_zone`, `tags`

**Outputs:** `vpc_id`, `public_subnet_id`, `private_subnet_id`

---

### 2. Security Module (`modules/security/`)
**Responsibility:** Network security through security groups

**Resources:**
- **ALB Security Group**
  - Ingress: 80 (HTTP), 443 (HTTPS) from 0.0.0.0/0
  - Egress: All traffic allowed
  
- **ECS Security Group**
  - Ingress: 8080 (container port) only from ALB
  - Egress: All traffic allowed (for pulling images, etc.)

**Inputs:** `app_name`, `vpc_id`, `container_port`, `tags`

**Outputs:** `alb_security_group_id`, `ecs_security_group_id`

---

### 3. IAM Module (`modules/iam/`)
**Responsibility:** Identity and access management

**Resources:**
- **Task Execution Role**
  - Pull images from ECR
  - Write logs to CloudWatch
  - AWS managed policy: `AmazonECSTaskExecutionRolePolicy`
  
- **Task Role**
  - For application-level permissions
  - Includes CloudWatch Logs policy
  - Extensible for app-specific needs

**Inputs:** `app_name`, `tags`

**Outputs:** `ecs_task_execution_role_arn`, `ecs_task_role_arn`

---

### 4. ALB Module (`modules/alb/`)
**Responsibility:** Load balancing and SSL/TLS

**Resources:**
- Application Load Balancer (in public subnet)
- Target Group (routes to ECS tasks on port 8080)
- HTTP Listener (port 80 → target group)
- HTTPS Listener (port 443 → HTTP 301 redirect)
- Self-signed certificate (for HTTPS)
- Health check configuration

**Inputs:** `app_name`, `vpc_id`, `public_subnet_id`, security group, `container_port`, `tags`

**Outputs:** `alb_dns_name`, `alb_arn`, `target_group_arn`

---

### 5. ECR Module (`modules/ecr/`)
**Responsibility:** Container image repository

**Resources:**
- ECR Repository
- Lifecycle Policy (keeps last 5 images, auto-deletes older ones)

**Inputs:** `app_name`, `tags`

**Outputs:** `repository_url`, `repository_name`, `registry_id`

---

### 6. ECS Module (`modules/ecs/`)
**Responsibility:** Container orchestration and auto-scaling

**Resources:**
- ECS Cluster (Fargate-only)
- CloudWatch Log Group
- Task Definition (pulls image from ECR)
- ECS Service (launches and manages tasks)
- Auto Scaling Target (2-4 tasks)
- Scaling Policies (CPU 70%, Memory 80%)

**Inputs:** All other modules' outputs, `container_image`, `task_cpu`, `task_memory`, `desired_count`, etc.

**Outputs:** `ecs_cluster_name`, `ecs_service_name`, `cloudwatch_log_group`

---

## Root Module Configuration

**Main File:** `main.tf`

```terraform
module "vpc" { ... }      # Creates VPC, subnets
module "security" { ... } # Creates security groups
module "iam" { ... }      # Creates IAM roles
module "alb" { ... }      # Creates load balancer
module "ecr" { ... }      # Creates ECR repository
module "ecs" { ... }      # Creates ECS cluster & service
```

**Variables File:** `variables.tf`
- Defines all input variables for the root module
- Default values where appropriate

**Values File:** `terraform.tfvars`
- Override defaults here
- CRITICAL: Update `container_image` with your ECR URL

**Outputs File:** `outputs.tf`
- Exposes important values from all modules
- Used for accessing ALB DNS, ECR URL, etc.

---

## Node.js Application

Located in `app/` directory:

### server.js
```javascript
const express = require('express');
const app = express();

app.get('/', (req, res) => {
  // Returns HTML: "Hello World" + service info
});

app.get('/health', (req, res) => {
  // Health check endpoint for ALB
  res.json({ status: 'healthy' });
});

app.listen(8080);
```

### Dockerfile
```dockerfile
# Stage 1: Build (installs dependencies)
FROM node:18-alpine AS builder
COPY package*.json ./
RUN npm ci --only=production

# Stage 2: Runtime (minimal layer)
FROM node:18-alpine
COPY --from=builder /app/node_modules ./node_modules
COPY server.js package.json .
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s CMD node -e "..."
CMD ["npm", "start"]
```

---

## Deployment Process (Step-by-Step)

### Manual Deployment

```bash
# 1️⃣ Build Docker image
cd app
docker build -t serverless-app:latest .
cd ..

# 2️⃣ Initialize Terraform
terraform init

# 3️⃣ Plan infrastructure
terraform plan -out=tfplan

# 4️⃣ Apply infrastructure (creates VPC, ALB, ECR, etc.)
terraform apply tfplan

# 5️⃣ Get ECR URL and push image
ECR_URL=$(terraform output -raw ecr_repository_url)
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin $ECR_URL
docker tag serverless-app:latest $ECR_URL:latest
docker push $ECR_URL:latest

# 6️⃣ Update terraform.tfvars
# Edit terraform.tfvars and set:
# container_image = "$ECR_URL:latest"

# 7️⃣ Deploy ECS service
terraform plan -out=tfplan
terraform apply tfplan

# 8️⃣ Get application URL
terraform output alb_dns_name
```

### Automated Deployment

**Windows (PowerShell):**
```powershell
.\deploy.ps1
```

**Linux/macOS (Bash):**
```bash
chmod +x deploy.sh
./deploy.sh
```

---

## Configuration Variables

Edit `terraform.tfvars` to customize:

| Variable | Default | Purpose |
|----------|---------|---------|
| `aws_region` | `us-east-1` | AWS region |
| `app_name` | `serverless-app` | Resource naming |
| `container_image` | (required) | ECR image URL:tag |
| `vpc_cidr` | `10.0.0.0/16` | VPC network |
| `public_subnet_cidr` | `10.0.1.0/24` | ALB subnet |
| `private_subnet_cidr` | `10.0.2.0/24` | ECS subnet |
| `availability_zone` | `us-east-1a` | AZ (single) |
| `container_port` | `8080` | Container listens on |
| `task_cpu` | `256` | CPU units (256/512/1024/2048/4096) |
| `task_memory` | `512` | Memory in MB |
| `desired_count` | `2` | Initial task count |

---

## Data Flow

### Request Flow
```
1. Internet client → ALB (port 80)
2. ALB → Target Group (health checks every 30s)
3. Target Group → ECS Task (port 8080)
4. ECS Task → Application (Express.js)
5. Response → ALB → Internet client
```

### Image Pull Flow
```
1. Task Definition specifies: ECR repo URL
2. ECS Task launches with Fargate
3. Task Execution Role pulls image from ECR
4. ECR authenticates task pulling image
5. Image loaded and container starts
6. Application listening on port 8080
```

### Logging Flow
```
1. Application logs to stdout
2. Container runtime captures logs
3. Logs sent to CloudWatch
4. Log Group: /ecs/serverless-app
5. 7-day retention
6. View: aws logs tail /ecs/serverless-app --follow
```

---

## Auto-Scaling Behavior

**Scaling Target:** 2-4 tasks

**Metrics & Thresholds:**
- CPU Utilization > 70% → Scale up
- Memory Utilization > 80% → Scale up
- CPU < 70% & Memory < 80% → Scale down

**Example:**
- 2 tasks at 50% CPU → No scaling
- 2 tasks at 80% CPU → Launch 3rd task
- 3 tasks at 60% CPU → Healthy
- 4 tasks at 40% CPU → Terminate task, back to 3

---

## Cost Breakdown

**Monthly Estimate (US East 1):**

| Service | Cost | Notes |
|---------|------|-------|
| ALB | $16.00 | Fixed hourly charge |
| ECS Fargate | $31.00 | 2 × (256 CPU + 512 MB) continual |
| ECR | $0.10 | Storage for images |
| CloudWatch Logs | $0.50 | 7-day retention |
| **Total** | **$47.60** | Excludes data transfer |

Data transfer costs vary based on usage (minimal for internal traffic).

---

## Troubleshooting

### Tasks not starting
**Symptoms:** Tasks show "PENDING" or fail to reach healthy
**Solutions:**
1. Check security groups: ALB must reach ECS on port 8080
2. Verify image exists in ECR
3. Check CloudWatch logs: `terraform output cloudwatch_log_group`
4. Verify task CPU/memory valid combination

### Application not accessible
**Symptoms:** ALB DNS unreachable or times out
**Solutions:**
1. Confirm ALB is running: `terraform output alb_dns_name`
2. Verify target group has healthy targets
3. Check security group ingress rules
4. Ensure name resolution working: `nslookup <ALB_DNS>`

### High memory usage
**Symptoms:** Tasks continuously restarting
**Solutions:**
1. Increase `task_memory` in terraform.tfvars
2. Check application for memory leaks
3. Monitor with CloudWatch Container Insights

### Image pull failures
**Symptoms:** "CannotPullContainerImage" error
**Solutions:**
1. Verify ECR URI is correct
2. Confirm image exists: `aws ecr list-images --repository-name serverless-app`
3. Check Task Execution Role has ECR permissions
4. Re-push image to ECR

---

## Advanced Usage

### Custom Environment Variables

Edit ECS module (`modules/ecs/main.tf`), add to container_definitions:

```hcl
environment = [
  {
    name  = "APP_ENV"
    value = "production"
  },
  {
    name  = "LOG_LEVEL"
    value = "info"
  }
]
```

### Multi-Region Deployment

Create separate directories:
```
deploy/
├── us-east-1/
│   └── terraform.tfvars
├── eu-west-1/
│   └── terraform.tfvars
```

### High Availability (Multi-AZ)

Duplicate private subnet in different AZ:
1. Add new `aws_subnet` in VPC module
2. Add new route table association
3. Update ECS module to use both subnets
4. Update ALB to span both AZs

### Custom Domain with Real Certificate

Replace self-signed cert in ALB module:
```hcl
certificate_arn = "arn:aws:acm:..."  # ACM certificate
```

---

## Maintenance

### Updating Application

```bash
# 1. Update code in app/
# 2. Build and push new image
cd app
docker build -t serverless-app:v2 .
docker push $ECR_URL:v2

# 3. Update terraform.tfvars
container_image = "$ECR_URL:v2"

# 4. Deploy (rolling update)
terraform apply
```

### Scaling Changes

```hcl
# terraform.tfvars
desired_count = 3  # Changes minimum scaling target
```

### Removing Old Images

```bash
# Keep last 5, auto-delete older
# Configured in ECR module lifecycle policy
# Manual cleanup:
aws ecr batch-delete-image \
  --repository-name serverless-app \
  --image-ids imageTag=<old_tag>
```

---

## Security Best Practices Applied

✅ Private subnet for tasks (no direct internet access)  
✅ Security groups restrict traffic (least privilege)  
✅ IAM roles limited to required permissions  
✅ CloudWatch logs for audit trail  
✅ HTTPS listener available (self-signed for demo)  
✅ Health checks protect from bad deployments  
✅ Auto-scaling prevents resource exhaustion  

---

## Cleanup

**Destroy all infrastructure:**
```bash
terraform destroy
```

This removes:
- All subnets and VPC
- ALB and target groups
- ECS cluster, service, and tasks
- ECR repository (⚠️ including images!)
- IAM roles and policies
- Security groups
- CloudWatch log group

**Note:** ECR images are deleted. Back up if needed.

---

## Support Resources

- **AWS Documentation:**
  - [ECS Fargate](https://docs.aws.amazon.com/ecs/latest/developerguide/launch_types.html#launch-type-fargate)
  - [Application Load Balancer](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)
  - [ECR](https://docs.aws.amazon.com/ecr/)

- **Terraform Documentation:**
  - [AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
  - [Best Practices](https://www.terraform.io/language/modules)

- **This Project:**
  - [README.md](README.md) - Complete documentation
  - [QUICKSTART.md](QUICKSTART.md) - Quick reference
  - Module files in `modules/*/main.tf`

---

**Version:** 1.0  
**Last Updated:** February 2026  
**Status:** Production Ready ✅

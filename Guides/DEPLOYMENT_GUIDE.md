# Deployment Guide - Modular Serverless Architecture

## 🎯 What You Have

A **complete, production-ready modular Terraform setup** with:

✅ **Modular Architecture** (6 independent modules)  
✅ **Simple Node.js App** (Hello World with health endpoint)  
✅ **ECR Integration** (pull images for ECS)  
✅ **Auto-Scaling** (2-4 tasks based on CPU/Memory)  
✅ **HTTPS Redirect** (443 → 80)  
✅ **CloudWatch Logging** (automatic logs)  
✅ **Deployment Scripts** (Windows PowerShell & Linux Bash)  

---

## 📁 Project Structure

```
.
├─ modules/                    # Reusable Terraform modules
│  ├─ vpc/                    # VPC, subnets, IGW, routes
│  ├─ security/               # Security groups
│  ├─ iam/                    # IAM roles & policies
│  ├─ alb/                    # Load balancer & listeners
│  ├─ ecr/                    # Container registry
│  └─ ecs/                    # ECS cluster & service
│
├─ app/                        # Node.js application
│  ├─ server.js               # Express server
│  ├─ package.json            # Dependencies
│  ├─ Dockerfile              # Multi-stage build
│  └─ README.md               # App documentation
│
├─ main.tf                     # Root module (orchestrates all modules)
├─ variables.tf               # Root input variables
├─ terraform.tfvars           # Your configuration (adjust this!)
├─ outputs.tf                 # Output values
│
├─ deploy.ps1                 # Windows deployment script
├─ deploy.sh                  # Linux/macOS deployment script
│
├─ README.md                  # Complete documentation
├─ ARCHITECTURE.md            # Architecture details
├─ QUICKSTART.md              # Quick reference
└─ .gitignore                 # Git ignore rules
```

---

## ⚠️ Important Notes

### Old Files (Can Delete)
These files from the initial non-modular setup can be safely deleted (not used):
- `vpc.tf`
- `security.tf`
- `iam.tf`
- `alb.tf`
- `ecs.tf`

The modular versions in `modules/` are what's being used now.

### Critical: Update terraform.tfvars
Before deployment, you MUST update `terraform.tfvars`:

```hcl
container_image = "<YOUR_ECR_URL>:latest"
```

This will be generated during deployment, so first deployment is interactive.

---

## 🚀 Quick Start (7 Steps)

### Option A: Automated Deployment (Recommended)

**Windows (PowerShell):**
```powershell
# Run from project root directory
.\deploy.ps1
```

**Linux/macOS:**
```bash
chmod +x deploy.sh
./deploy.sh
```

This automates all 7 steps below.

### Option B: Manual Step-by-Step

#### Step 1: Prerequisites
Ensure you have:
- ✅ Docker installed and running
- ✅ Terraform installed (`terraform --version`)
- ✅ AWS CLI installed (`aws --version`)
- ✅ AWS credentials configured (`aws sts get-caller-identity`)
- ✅ Permission to create: VPC, ALB, ECS, ECR, IAM

#### Step 2: Build Docker Image

```bash
cd app
docker build -t serverless-app:latest .
```

Test locally (optional):
```bash
docker run -p 8080:8080 serverless-app:latest
# Visit http://localhost:8080
```

#### Step 3: Initialize Terraform

```bash
cd ..
terraform init
```

This downloads AWS provider and prepares `.terraform/` directory.

#### Step 4: Validate Configuration

```bash
terraform validate
```

Checks for syntax errors.

#### Step 5: Plan Infrastructure

```bash
terraform plan -out=tfplan
```

Shows what will be created. Review the output!

**Key resources:**
- 1 VPC with subnets
- 1 ALB with listeners
- 1 ECR repository
- 1 ECS cluster
- Security groups, IAM roles, etc.

#### Step 6: Apply Infrastructure

```bash
terraform apply tfplan
```

**This creates:** VPC, ALB, ECR, ECS cluster, security groups, logging, etc.

**Duration:** 3-5 minutes

**Output:** ECR repository URL

#### Step 7: Push Docker Image & Deploy Service

```bash
# Get ECR URL from Terraform output
ECR_URL=$(terraform output -raw ecr_repository_url)
echo "ECR URL: $ECR_URL"

# Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin $ECR_URL

# Tag image
docker tag serverless-app:latest $ECR_URL:latest

# Push to ECR
docker push $ECR_URL:latest
```

#### Step 8: Update Configuration & Deploy Service

Edit `terraform.tfvars`:

```hcl
# Replace this:
container_image = "<YOUR_ECR_IMAGE_URL>:latest"

# With your actual ECR URL, example:
# container_image = "123456789.dkr.ecr.us-east-1.amazonaws.com/serverless-app:latest"
```

Deploy:
```bash
terraform plan -out=tfplan
terraform apply tfplan
```

**Duration:** 5-10 minutes for ECS service to be ready

#### Step 9: Access Application

```bash
# Get ALB DNS name
ALB_DNS=$(terraform output -raw alb_dns_name)
echo "Visit: http://$ALB_DNS"
```

Open in browser: http://<your-alb-dns>

You should see: **"Hello World"** page! ✅

---

## ✅ Verification Checklist

After deployment, verify everything:

```bash
# 1. Check ALB is responding
curl http://$(terraform output -raw alb_dns_name)

# 2. Check ECS service is healthy
CLUSTER=$(terraform output -raw ecs_cluster_name)
SERVICE=$(terraform output -raw ecs_service_name)
aws ecs describe-services \
  --cluster $CLUSTER \
  --services $SERVICE \
  --region us-east-1

# 3. Check logs
LOG_GROUP=$(terraform output -raw cloudwatch_log_group)
aws logs tail $LOG_GROUP --follow --region us-east-1

# 4. Verify ECR has your image
aws ecr list-images --repository-name serverless-app
```

---

## 📊 Monitoring & Maintenance

### View Application Logs

```bash
# Real-time logs
aws logs tail /ecs/serverless-app --follow

# Last 100 lines
aws logs tail /ecs/serverless-app --max-items 100
```

### Check Service Status

```bash
# List running tasks
aws ecs list-tasks --cluster serverless-app-cluster

# Get task details
aws ecs describe-tasks \
  --cluster serverless-app-cluster \
  --tasks <task-arn>
```

### Scale Application

Edit `terraform.tfvars`:
```hcl
desired_count = 3  # Change from 2 to 3
```

Apply changes:
```bash
terraform apply
```

ECS will maintain 3 tasks (auto-scales between 2-4 based on metrics).

### Update Application Code

1. Edit `app/server.js`
2. Build new image: `docker build -t serverless-app:v2 .`
3. Push to ECR: `docker push $ECR_URL:v2`
4. Update `terraform.tfvars`: `container_image = "$ECR_URL:v2"`
5. Deploy: `terraform apply`

ECS handles rolling update (old tasks → new tasks).

---

## 🧹 Cleanup

**To destroy everything (delete all AWS resources):**

```bash
terraform destroy
```

⚠️ This deletes:
- VPC, subnets, IGW
- ALB, target groups
- ECS cluster, service, tasks
- ECR repository (including images!)
- IAM roles
- Security groups
- CloudWatch logs

**To keep ECR images, manually delete ECS:**
```bash
terraform destroy -target="module.ecs"
# Keep ECR with: terraform destroy -target="module.ecr" --auto-approve=false
```

---

## 🔧 Customization

### Change Region

Edit `terraform.tfvars`:
```hcl
aws_region = "eu-west-1"
availability_zone = "eu-west-1a"
```

### Change Task Resources

```hcl
# CPU: 256, 512, 1024, 2048, 4096
task_cpu = 512

# Memory (must be compatible with CPU)
task_memory = 1024
```

### Change Auto-Scaling

Edit `modules/ecs/main.tf`:
```hcl
# Change max capacity
resource "aws_appautoscaling_target" "ecs" {
  max_capacity = 6  # was 4
  min_capacity = 2  # was desired_count
}

# Change thresholds
target_tracking_scaling_policy_configuration {
  target_value = 50.0  # was 70.0
}
```

### Use Real Certificate (Production)

1. Request ACM certificate in AWS Console
2. Edit `modules/alb/main.tf`:
```hcl
certificate_arn = "arn:aws:acm:..."  # Your ACM certificate
```

### Add Environment Variables

Edit `modules/ecs/main.tf`, in container_definitions:
```hcl
environment = [
  {
    name  = "DATABASE_URL"
    value = "postgresql://..."
  }
]
```

---

## 🐛 Troubleshooting

### "terraform init" fails
- Check AWS credentials: `aws sts get-caller-identity`
- Check internet connection
- Try again with: `terraform init -upgrade`

### "docker push" fails
- Ensure ECR login: `aws ecr get-login-password ... | docker login ...`
- Verify image exists: `docker images | grep serverless-app`
- Verify ECR repo exists: `terraform output ecr_repository_url`

### Tasks not becoming healthy
- Check CloudWatch logs: `aws logs tail /ecs/serverless-app --follow`
- Verify image exists in ECR: `aws ecr list-images --repository-name serverless-app`
- Check security groups: ALB must reach ECS on port 8080
- Verify container_image in terraform.tfvars is correct

### Application returns 502 (Bad Gateway)
- Check if tasks are running: `aws ecs list-tasks --cluster serverless-app-cluster`
- Check if health check passes: See CloudWatch logs
- Ensure container is listening on port 8080

### "No target healthy" in ALB
- Check target group health in AWS Console
- Verify port 8080 is exposed in Dockerfile
- Check application startup logs

---

## 📚 Documentation Files

| File | Purpose |
|------|---------|
| **README.md** | Complete feature documentation |
| **QUICKSTART.md** | Quick reference guide |
| **ARCHITECTURE.md** | Detailed architecture explanation |
| **DEPLOYMENT_GUIDE.md** | This file - step-by-step deployment |
| **app/README.md** | Application documentation |
| **modules/*/main.tf** | Module implementation details |

---

## 🎓 Learning Resources

### Understanding the Architecture

1. **Modular Design:** Each `modules/` directory is self-contained
2. **Dependency Flow:** `main.tf` orchestrates module dependencies
3. **Outputs:** Modules export values for other modules to use
4. **Inputs:** Modules accept configuration through variables

Example:
```
main.tf
  ├─> module.vpc (creates VPC)
  │    └─ outputs: vpc_id
  │
  ├─> module.security (needs vpc_id from VPC)
  │    └ inputs: vpc_id
  │    └ outputs: security_group_ids
  │
  └─> module.ecs (needs outputs from all modules)
       └ inputs: subnet_ids, sg_ids, roles_arns, etc.
```

### Container Orchestration

1. **Docker:** Packages application + dependencies
2. **ECR:** Stores Docker images
3. **ECS:** Orchestrates running containers
4. **Fargate:** Serverless container compute (no EC2)

### Load Balancing

1. **ALB:** Distributes traffic across targets
2. **Health Checks:** Removes unhealthy targets
3. **Target Groups:** Rules for routing
4. **Listeners:** Port-based entry points

---

## 🚀 Next Steps

### For Learning
1. Read [ARCHITECTURE.md](ARCHITECTURE.md) for detailed overview
2. Explore module files: `modules/*/main.tf`
3. Experiment with variables in `terraform.tfvars`
4. Try scaling the application up/down

### For Production
1. Use multi-AZ setup (add second AZ & subnets)
2. Get real SSL certificate (ACM)
3. Set up custom domain (Route 53)
4. Enable CloudWatch alarms (SNS notifications)
5. Implement CI/CD pipeline (GitHub Actions, CodePipeline)
6. Add database (RDS, DynamoDB)
7. Add caching (ElastiCache)

### For Development
1. Modify `app/server.js` with your code
2. Build & test locally: `docker run -p 8080:8080 serverless-app:latest`
3. Push to ECR with version tag: `docker push $ECR_URL:v1`
4. Deploy: Update `terraform.tfvars` and `terraform apply`

---

## 💡 Pro Tips

✅ **Always run `terraform plan` before `terraform apply`**  
✅ **Use `terraform.tfvars` for environment-specific values**  
✅ **Keep module outputs minimal (only expose what's needed)**  
✅ **Tag all resources for cost allocation**  
✅ **Use CloudWatch logs for debugging**  
✅ **Test Docker image locally before pushing**  
✅ **Version your ECR images with tags (v1, v2, latest)**  

---

## 📞 Getting Help

**Error message in Terraform?**
- Check syntax: `terraform validate`
- Check AWS permissions: `aws sts get-caller-identity`
- Read error message carefully (AWS error codes are descriptive)

**Container not starting?**
- Check CloudWatch logs: `terraform output cloudwatch_log_group`
- Verify image: `aws ecr list-images`
- Check port: Dockerfile exposes 8080?

**General help:**
- AWS Docs: https://docs.aws.amazon.com
- Terraform Docs: https://www.terraform.io/docs
- Press `terraform -help` for CLI help

---

**You're ready to deploy! 🎉**

Start with: `./deploy.ps1` (Windows) or `./deploy.sh` (Linux)

Good luck! 🚀

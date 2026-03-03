# Backend Setup & Remote State Integration

## Quick Start (5 Minutes)

### Step 1: Deploy Backend Infrastructure

```bash
# Navigate to backend directory
cd backend

# Initialize with local state
terraform init

# Review and confirm
terraform plan

# Create S3 + DynamoDB
terraform apply
```

**Note the outputs:**
```
s3_bucket_name = "terraform-state-serverless-app-XXXXXXXXXXXX"
dynamodb_table_name = "terraform-serverless-app-terraform-locks"
```

### Step 2: Configure Main Infrastructure Backend

```bash
# Navigate to dev directory
cd ../dev

# Initialize with remote backend
terraform init \
  -backend-config="bucket=terraform-state-serverless-app-XXXXXXXXXXXX" \
  -backend-config="dynamodb_table=terraform-serverless-app-terraform-locks" \
  -backend-config="region=us-east-1" \
  -backend-config="encrypt=true"

# Verify connection
terraform backend show
```

### Step 3: Deploy Your Infrastructure

```bash
# Normal Terraform workflow now
terraform plan
terraform apply
```

**✓ Done!** Your state is now centrally managed in AWS.

---

## File Structure Explained

```
backend/                             ← Backend Infrastructure (Deploy FIRST)
├── main.tf                          # S3 bucket + DynamoDB table
├── variables.tf                     # Backend configuration parameters
├── terraform.tfvars                 # Backend values
└── README.md                        # Detailed backend documentation

dev/                                 ← Main Infrastructure (Deploy SECOND)
├── backend.tf                       # Backend configuration (newly added)
├── main.tf                          # Modular infrastructure
├── terraform.tfvars                 # Infrastructure values
├── variables.tf                     # Infrastructure parameters
└── outputs.tf                       # Exported values
```

---

## Why Remote State + Locking?

### Problem it Solves

| Scenario | Without Locking | With Locking |
|----------|-----------------|--------------|
| **Concurrent Changes** | State corruption | Prevented |
| **Team Collaboration** | Drift/conflicts | Synchronized |
| **Accidental Deletion** | Lost state | Versioned recovery |
| **Lost Credential** | In local state | Encrypted in S3 |

### Example: Preventing State Corruption

```
❌ BAD (Local State)          ✅ GOOD (Remote State + Lock)
─────────────────────────── ───────────────────────────────

User A applies              User A applies
  ↓                           ↓
User B applies (conflict!)  User B waits (locked)
  ↓                           ↓
State corrupted             User A completes + unlocks
                              ↓
                            User B applies (succeeds)
```

---

## AWS Resources Created

### S3 Bucket Configuration

The backend creates a versioned S3 bucket with:

- **Encryption:** AES256 (at rest)
- **Versioning:** Enabled (keeps full history)
- **Public Access:** Blocked (security)
- **Lifecycle Policy:** Auto-cleanup after 90 days
- **State Path:** `s3://bucket/serverless-app/terraform.tfstate`

### DynamoDB Table Configuration

The backend creates a DynamoDB table with:

- **Table Name:** `terraform-serverless-app-terraform-locks`
- **Hash Key:** `LockID` (Terraform standard)
- **Billing:** On-demand (cost-effective)
- **PITR:** Enabled (disaster recovery)
- **Auto-backup:** Enabled

---

## Integration with Main Infrastructure

### What Changed in dev/

**New file:** `dev/backend.tf`

```hcl
terraform {
  backend "s3" {
    key            = "serverless-app/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    skip_region_validation = false
    dynamodb_table = "terraform-serverless-app-terraform-locks"
  }
}
```

This file tells Terraform where to store state. Backend config is passed via `terraform init`:

```bash
terraform init \
  -backend-config="bucket=YOUR_BUCKET" \
  -backend-config="dynamodb_table=YOUR_TABLE" \
  -backend-config="region=us-east-1" \
  -backend-config="encrypt=true"
```

**No changes to:** main.tf, variables.tf, outputs.tf, or module code.

---

## Common Operations

### Check Backend Status

```bash
cd dev
terraform backend show
```

Output shows active backend configuration.

### View All Resources in State

```bash
terraform state list
```

Example output:
```
module.alb.aws_lb.main
module.ecr.aws_ecr_repository.app
module.ecs.aws_ecs_cluster.main
module.ecs.aws_ecs_service.app
module.ecs.aws_ecs_task_definition.app
module.ecs.aws_autoscaling_target.ecs_target
module.ecs.aws_autoscaling_policy.cpu_scaling
module.ecs.aws_autoscaling_policy.memory_scaling
module.iam.aws_iam_role.ecs_task_execution_role
module.iam.aws_iam_role.ecs_task_role
module.security.aws_security_group.alb
module.security.aws_security_group.ecs
module.vpc.aws_vpc.main
```

### Backup State File

```bash
# Download current state to local file
terraform state pull > backup.tfstate

# Keep in safe location (not Git)
```

### Inspect Specific Resource

```bash
terraform state show module.vpc.aws_vpc.main
```

---

## Troubleshooting

### Issue: "Backend reinitialization required"

```
Error: Error releasing the state lock
Lock Info:
  ID:        f90adfcc-c47c-f127-d8c9-11f3a0e30e84
  Path:      terraform.tfstate
```

**Solution:** The lock is stuck. Clear it:

```bash
aws dynamodb delete-item \
  --table-name terraform-serverless-app-terraform-locks \
  --key '{"LockID": {"S": "serverless-app/terraform.tfstate"}}' \
  --region us-east-1
```

Then retry:
```bash
terraform apply
```

### Issue: "AccessDenied" on S3

**Verify IAM permissions:**

```bash
# Check who you are
aws sts get-caller-identity

# Verify S3 bucket
aws s3 ls | grep terraform-state

# Verify DynamoDB table
aws dynamodb list-tables
```

**Required IAM permissions:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::terraform-state-serverless-app-*",
        "arn:aws:s3:::terraform-state-serverless-app-*/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/terraform-serverless-app-*"
    }
  ]
}
```

### Issue: DynamoDB "TableNotFoundException"

```bash
# Check if table is active
aws dynamodb describe-table \
  --table-name terraform-serverless-app-terraform-locks \
  --query 'Table.TableStatus'

# Should return: ACTIVE
```

---

## Deployment Sequence

### First Time Setup

```
1. Deploy Backend Infrastructure
   └─ cd backend && terraform apply
   
2. Get backend outputs
   └─ terraform output
   
3. Configure dev with backend
   └─ cd ../dev && terraform init -backend-config=...
   
4. Deploy main infrastructure
   └─ terraform apply
```

### Regular Operations (After Setup)

```
cd dev
terraform plan
terraform apply
# State automatically handled!
```

---

## Cost Breakdown

**Backend Infrastructure Only:**

| Resource | Price | Notes |
|----------|-------|-------|
| S3 Storage | ~$0.02/month | ~100 KB state |
| S3 Versioning | ~$0.10/month | Old versions |
| DynamoDB | ~$1.00/month | On-demand, minimal |
| **Total** | **~$1.12/month** | Very economical |

---

## Cleanup (Only If Needed)

**⚠️  WARNING: Backup state before cleanup!**

```bash
# 1. Backup state
cd dev
terraform state pull > backup.tfstate

# 2. Remove backend config (switch to local)
rm backend.tf
terraform init -migrate-state

# 3. Destroy backend infrastructure
cd ../backend
terraform destroy

# 4. Delete S3 bucket if force_destroy = true
# (Terraform handles this automatically)
```

---

## Multi-Environment Setup (Advanced)

For dev/staging/prod environments:

```
backend/                            # Single shared backend
├── main.tf
└── terraform.tfvars

infrastructure/
├── dev/
│   ├── backend.tf
│   └── terraform.tfvars
├── staging/
│   ├── backend.tf
│   └── terraform.tfvars
└── prod/
    ├── backend.tf
    └── terraform.tfvars
```

Each environment uses unique state path:

```hcl
# infrastructure/dev/backend.tf
backend "s3" {
  key            = "dev/terraform.tfstate"
  bucket         = "terraform-state-serverless-app-123456789012"
  dynamodb_table = "terraform-serverless-app-terraform-locks"
}

# infrastructure/prod/backend.tf
backend "s3" {
  key            = "prod/terraform.tfstate"
  bucket         = "terraform-state-serverless-app-123456789012"
  dynamodb_table = "terraform-serverless-app-terraform-locks"
}
```

---

## Validation Checklist

After backend setup:

- [ ] `backend/` directory deployed
- [ ] S3 bucket created
- [ ] DynamoDB table active
- [ ] `terraform backend show` displays remote backend
- [ ] `terraform plan` works
- [ ] State file uploaded to S3
- [ ] Lock table accessible
- [ ] All modules load correctly
- [ ] Team members can access same state

---

## Resources

- [Terraform S3 Backend](https://www.terraform.io/language/settings/backends/s3)
- [AWS S3 Documentation](https://docs.aws.amazon.com/s3/)
- [AWS DynamoDB Documentation](https://docs.aws.amazon.com/dynamodb/)
- [Terraform State Locking](https://www.terraform.io/language/state/locking)

---

**Status:** ✅ Production Ready  
**Backend Version:** 1.0  
**Last Updated:** February 2026

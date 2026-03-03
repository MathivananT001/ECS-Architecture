# Remote State Backend Setup Guide

## Overview

This backend configuration stores Terraform state in **AWS S3** with **DynamoDB locking**, ensuring:

✅ **Single Source of Truth** - State centralized in S3  
✅ **State Locking** - DynamoDB prevents concurrent modifications  
✅ **State Drift Prevention** - Remote state always in sync  
✅ **Global Access** - Team members access same state  
✅ **Encryption** - S3 encryption at rest  
✅ **Versioning** - Full history of state changes  
✅ **PITR Recovery** - DynamoDB point-in-time recovery  

---

## Architecture

```
┌─────────────────────────────────────────────────┐
│  Your Local Terraform                           │
│  (dev/ directory)                               │
└────────────────┬────────────────────────────────┘
                 │
                 │ terraform init
                 │ terraform plan/apply
                 │
        ┌────────▼──────────────┐
        │ AWS Backend           │
        │ ┌──────────────────┐  │
        │ │ S3 Bucket        │  │ State Storage
        │ │ - terraform.*    │  │ - Versioning enabled
        │ │ - Encrypted      │  │ - Point-in-time recovery
        │ └──────────────────┘  │
        │                       │
        │ ┌──────────────────┐  │
        │ │ DynamoDB Table   │  │ State Locking
        │ │ - LockID         │  │ - Prevents parallel runs
        │ │ - Auto-cleanup   │  │ - PITR enabled
        │ └──────────────────┘  │
        └───────────────────────┘
```

---

## Directory Structure

```
Project Root/
├── backend/                      # ← Backend resources (CREATE FIRST!)
│   ├── main.tf                   # S3 + DynamoDB infrastructure
│   ├── variables.tf              # Backend variables
│   ├── terraform.tfvars          # Backend config
│   └── README.md                 # Backend documentation
│
├── dev/                          # ← Main infrastructure (CREATE SECOND)
│   ├── main.tf                   # Modular infrastructure
│   ├── backend.tf                # Backend configuration (NEW!)
│   ├── variables.tf              # Infrastructure variables
│   ├── terraform.tfvars          # Infrastructure config
│   └── outputs.tf                # Infrastructure outputs
│
├── modules/                      # Modular components
│   ├── vpc/
│   ├── security/
│   ├── iam/
│   ├── alb/
│   ├── ecr/
│   └── ecs/
│
└── app/                          # Node.js application
```

---

## Step-by-Step Setup

### Phase 1: Create Backend Infrastructure

The backend resources (S3 + DynamoDB) must be created **FIRST** and use **local state**.

```bash
# 1. Navigate to backend directory
cd backend

# 2. Initialize Terraform (local state, in current directory)
terraform init

# 3. Review what will be created
terraform plan

# 4. Create S3 bucket and DynamoDB table
terraform apply

# 5. Capture outputs - you'll need these!
terraform output
```

**Outputs you'll see:**
```
s3_bucket_name = "terraform-state-serverless-app-123456789012"
dynamodb_table_name = "terraform-serverless-app-terraform-locks"
backend_config_command = "terraform init -backend-config='bucket=...' ..."
```

**Important:** Save these values! You'll need the S3 bucket name and DynamoDB table name.

### Phase 2: Configure Main Infrastructure Backend

Now configure the main infrastructure to use the remote backend.

```bash
# 1. Navigate to dev directory
cd ../dev

# 2. Option A: Use the command from backend output
terraform init \
  -backend-config="bucket=terraform-state-serverless-app-123456789012" \
  -backend-config="dynamodb_table=terraform-serverless-app-terraform-locks" \
  -backend-config="region=us-east-1" \
  -backend-config="encrypt=true"

# 2. Option B: Use environment variables
export TF_BACKEND_BUCKET="terraform-state-serverless-app-123456789012"
export TF_BACKEND_DYNAMODB_TABLE="terraform-serverless-app-terraform-locks"
terraform init

# 3. Verify backend configuration
terraform backend show

# 4. Now deploy main infrastructure normally
terraform plan
terraform apply
```

**Result:** State is now stored in S3, locked by DynamoDB!

---

## State File Details

### S3 Configuration

| Feature | Details |
|---------|---------|
| **Bucket Name** | `terraform-state-serverless-app-<account-id>` |
| **State Path** | `s3://bucket/serverless-app/terraform.tfstate` |
| **Encryption** | AES256 (enabled by default) |
| **Versioning** | Enabled (maintains full history) |
| **Public Access** | Blocked (security) |
| **Lifecycle** | Old versions deleted after 90 days |

### DynamoDB Table

| Feature | Details |
|---------|---------|
| **Table Name** | `terraform-serverless-app-terraform-locks` |
| **Hash Key** | `LockID` (string) |
| **Billing Mode** | On-demand (pay-per-request) |
| **PITR** | Enabled (point-in-time recovery) |
| **Auto-Backup** | Enabled |

---

## How State Locking Works

### Without Locking (Bad ❌)
```
User A: terraform apply      User B: terraform apply
        ↓                             ↓
    [Read State]            [Read State]
        ↓                             ↓
    [Modify]                 [Modify]
        ↓                             ↓
    [Write State] ----→ STATE CONFLICT ←---- [Write State]
    
Result: State corruption! One change is lost!
```

### With DynamoDB Locking (Good ✅)
```
User A: terraform apply      User B: terraform apply
        ↓                             ↓
    [Lock] ✓                 [Lock] ✗ (BLOCKED)
        ↓                             │
    [Read State]                      │
        ↓                             │
    [Modify]                          │
        ↓                             │
    [Write State]                     │
        ↓                             │
    [Unlock]                    (Lock acquired!)
        ✓                            ↓
                              [Read State]
                                   ↓
                              [Modify]
                                   ↓
                              [Write State]
                                   ↓
                              [Unlock]

Result: Sequential execution, state always consistent!
```

---

## Troubleshooting

### Error: "Backend reinitialization required"

```
Error: Error releasing the state lock
```

**Solution:**
```bash
# Recreate lock if it gets stuck
aws dynamodb delete-item \
  --table-name terraform-serverless-app-terraform-locks \
  --key '{"LockID": {"S": "serverless-app/terraform.tfstate"}}'

# Then retry
terraform apply
```

### Error: "AccessDenied" on S3

**Solution:**
```bash
# Ensure IAM user has S3 and DynamoDB permissions
# Check AWS credentials
aws sts get-caller-identity

# Verify S3 bucket exists
aws s3 ls terraform-state-serverless-app-*

# Verify DynamoDB table exists
aws dynamodb list-tables
```

### Error: "InvalidParameterException" on DynamoDB

```
Error: One or more parameter values were invalid
```

**Solution:**
```bash
# Verify lock table exists and is active
aws dynamodb describe-table \
  --table-name terraform-serverless-app-terraform-locks \
  --query 'Table.TableStatus'

# Should return: ACTIVE
```

---

## Daily Operations

### Normal Workflow

```bash
# 1. Navigate to dev directory
cd dev

# 2. Backend state is automatically loaded
terraform plan

# 3. Make your changes
terraform apply

# 4. State is automatically locked during apply
# Watch for: "Acquiring state lock..."
# State is unlocked after apply completes
```

### Viewing Lock Status

```bash
# Check if state is currently locked
aws dynamodb get-item \
  --table-name terraform-serverless-app-terraform-locks \
  --key '{"LockID": {"S": "serverless-app/terraform.tfstate"}}'

# If returns item: state is locked
# If returns nothing: state is unlocked
```

### Inspecting Remote State

```bash
# Show remote backend configuration
terraform backend show

# Download state file to local (creates backup)
terraform state pull > terraform.tfstate.backup

# List all resources in state
terraform state list

# Show specific resource
terraform state show module.vpc.aws_vpc.main
```

### Migrating State (If Needed)

```bash
# Pull remote state to local
terraform state pull > local.tfstate

# Switch backend config in dev/terraform.tfvars
# Then push back
terraform state push local.tfstate
```

---

## Security Best Practices

✅ **S3 Bucket**
- Public access blocked (configured)
- Encryption enabled (AES256)
- Versioning enabled
- Lifecycle policy active (old versions deleted)

✅ **DynamoDB Table**
- Point-in-time recovery enabled
- Automatic backups enabled
- On-demand billing (no capacity planning)

✅ **Access Control**
- Use IAM policies to restrict who can access backend
- Enable MFA for sensitive operations
- Audit CloudTrail logs

✅ **Sensitive Data**
- Credentials in state are encrypted at rest
- Consider using Vault for secret management
- Never commit state files to Git

---

## Cost Estimate

**Monthly (US East 1):**

| Service | Cost | Notes |
|---------|------|-------|
| S3 Storage | ~$0.02 | ~100 KB state file |
| S3 Versioning | ~$0.10 | Stores 30-40 versions |
| DynamoDB | ~$1.00 | On-demand, minimal usage |
| **Total** | **~$1.12** | Very economical! |

---

## Cleanup (If Needed)

**⚠️ WARNING: Back up state before cleanup!**

```bash
# 1. Back up state
terraform state pull > backup.tfstate

# 2. Remove remote backend config
rm dev/backend.tf

# 3. Reinitialize with local state
cd dev
terraform init -migrate-state

# 4. Destroy backend infrastructure
cd ../backend
terraform destroy
```

---

## Multi-Environment Setup

For multiple environments (dev/staging/prod):

```
backend/                        # Single shared backend
├── main.tf
├── variables.tf
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

Each environment uses different backend state path:
```hcl
# dev/backend.tf
key = "dev/terraform.tfstate"

# staging/backend.tf
key = "staging/terraform.tfstate"

# prod/backend.tf
key = "prod/terraform.tfstate"
```

---

## Validation Checklist

After setup:

- [ ] Backend S3 bucket created
- [ ] DynamoDB table created
- [ ] `terraform init` completed with backend config
- [ ] `terraform backend show` displays remote backend
- [ ] `terraform plan` works without errors
- [ ] State file shown in S3 console (s3://bucket/serverless-app/terraform.tfstate)
- [ ] DynamoDB table is active
- [ ] CloudWatch logs show successful operations
- [ ] Team members can access same state

---

## Quick Reference Commands

```bash
# Backend setup
cd backend && terraform init && terraform apply

# Main infrastructure with remote backend
cd ../dev
terraform init -backend-config="bucket=..." -backend-config="dynamodb_table=..."

# Check backend status
terraform backend show

# Pull state locally (backup)
terraform state pull > backup.tfstate

# Clean up lock if stuck
aws dynamodb delete-item --table-name <table> --key '{"LockID": {"S": "<key>"}}'

# Destroy everything (dev infrastructure first!)
cd ../dev && terraform destroy
cd ../backend && terraform destroy
```

---

## Resources

- [Terraform S3 Backend](https://www.terraform.io/language/settings/backends/s3)
- [AWS S3 Documentation](https://docs.aws.amazon.com/s3/)
- [AWS DynamoDB Documentation](https://docs.aws.amazon.com/dynamodb/)
- [State Locking](https://www.terraform.io/language/state/locking)

---

**Setup Status:** ✅ Production Ready  
**Last Updated:** February 2026  
**Version:** 1.0

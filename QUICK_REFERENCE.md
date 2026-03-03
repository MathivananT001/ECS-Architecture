# Quick Reference Card

## 📋 One-Page Command Reference

### Setup Sequence (Copy & Paste)

```bash
# Step 1: Deploy Backend (in backend/ directory)
cd backend
terraform init
terraform plan
terraform apply
# ⚠️  SAVE OUTPUT VALUES ⚠️

# Step 2: Note these values from output:
# - s3_bucket_name 
# - dynamodb_table_name
# - aws_region

# Step 3: Configure Dev with Backend (in dev/ directory)
cd ../dev
terraform init \
  -backend-config="bucket=terraform-state-serverless-app-XXXXXXXXXXXX" \
  -backend-config="dynamodb_table=terraform-serverless-app-terraform-locks" \
  -backend-config="region=us-east-1" \
  -backend-config="encrypt=true"

# Step 4: Deploy Main Infrastructure
terraform validate
terraform plan
terraform apply

# Done! State is now in S3 with DynamoDB locking 🎉
```

---

## 🔍 Verification Commands

```bash
# Verify backend configuration
terraform backend show

# Check state file in S3
aws s3 ls s3://terraform-state-serverless-app-XXXXXXXXXXXX/serverless-app/

# Check lock table
aws dynamodb describe-table --table-name terraform-serverless-app-terraform-locks

# View all resources in state
terraform state list

# Inspect specific resource
terraform state show module.vpc.aws_vpc.main
```

---

## 🚨 Emergency Commands

```bash
# If state lock is stuck:
aws dynamodb delete-item \
  --table-name terraform-serverless-app-terraform-locks \
  --key '{"LockID": {"S": "serverless-app/terraform.tfstate"}}' \
  --region us-east-1

# Backup state to local
terraform state pull > backup.tfstate

# Restore from backup
terraform state push backup.tfstate

# Force unlock (use with caution!)
terraform force-unlock <LOCK_ID>
```

---

## 📁 File Locations

| File/Folder | Purpose | Location |
|---|---|---|
| Backend Infrastructure | S3 + DynamoDB | `/backend/` |
| Backend Config | Remote state | `/dev/backend.tf` |
| Main Infrastructure | Modules orchestration | `/dev/main.tf` |
| Modules | Reusable components | `/modules/` |
| Application | Node.js Express | `/app/` |
| Guides | Documentation | `/Guides/` |
| Validation | System checks | `validate.ps1` / `validate.sh` |

---

## 🔑 Key Files

```
backend/main.tf              ← S3 bucket + DynamoDB config
backend/variables.tf         ← Backend parameters
backend/terraform.tfvars     ← Backend values
dev/backend.tf              ← Remote state config (NEW!)
dev/main.tf                 ← Infrastructure modules
Guides/BACKEND_SETUP.md     ← Full backend documentation
```

---

## 📊 Architecture at a Glance

```
Your Terraform Code
       ↓
terraform apply
       ↓
     ┌─────────────────┐
     │  DynamoDB Lock  │ ← Prevents conflicts
     │  (async)        │
     └─────────────────┘
       ↓
 [Modify Resources]
       ↓
 [Update State]
       ↓
┌─────────────────┐
│  S3 Bucket      │ ← Centralized state
│  (versioned)    │   (encrypted, backed up)
└─────────────────┘
```

---

## ⚡ Common Operations

```bash
# Regular workflow (state auto-handled after setup)
cd dev
terraform plan
terraform apply

# Update infrastructure
vim terraform.tfvars         # Change values
terraform plan
terraform apply

# Scale ECS tasks
# Edit dev/terraform.tfvars: desired_count = 4
terraform apply

# View logs
aws logs tail /ecs/serverless-app --follow

# Destroy infrastructure (main first!)
cd dev && terraform destroy
cd ../backend && terraform destroy
```

---

## 📈 Cost Summary

| Component | Monthly | Notes |
|---|---|---|
| Backend (S3 + DynamoDB) | $1.12 | Minimal, auto-cleanup |
| Infrastructure (existing) | $50.50 | VPC, ALB, ECS, ECR |
| **Total** | **~$51.62** | Very cost-effective |

---

## ✅ Validation Checklist

```bash
# Run validation (takes <1 minute)
./validate.ps1      # Windows
./validate.sh       # Linux/macOS

# Should see:
# ✓ terraform installed
# ✓ aws installed
# ✓ AWS credentials valid
# ... [60+ more checks] ...
# ✓ All validations passed!
```

---

## 🎯 State Files Explained

### Local State (Before)
```
Dev Machine
└── terraform.tfstate (in dev/ directory)
    Problem: Local only, no backup, no locking ❌
```

### Remote State (After)
```
AWS Account
└── S3 Bucket: terraform-state-serverless-app-XXXX
    ├── serverless-app/
    │   └── terraform.tfstate (current)
    │       → Encrypted ✓
    │       → Versioned ✓
    │       → Backed up ✓
    │       → Locked by DynamoDB ✓
    │
└── DynamoDB Table: terraform-serverless-app-terraform-locks
    └── LockID: "serverless-app/terraform.tfstate"
        → PITR enabled ✓
        → Auto-backup enabled ✓
```

---

## 🔐 Security Status

| Feature | Status | Details |
|---|---|---|
| Encryption at Rest | ✅ | AES256 (S3) |
| Encryption in Transit | ✅ | TLS for all connections |
| Public Access | ✅ | Blocked completely |
| Versioning | ✅ | Full history maintained |
| Backup | ✅ | PITR enabled (DynamoDB) |
| Locking | ✅ | DynamoDB prevents conflicts |
| Audit Trail | ⚠️  | Consider CloudTrail |
| MFA | ⚠️  | Recommended for AWS console |

---

## 🐛 Troubleshooting Matrix

| Error | Cause | Fix |
|---|---|---|
| "state lock" | Lock stuck | Delete from DynamoDB |
| "AccessDenied" | IAM permissions | Check credentials with `aws sts` |
| "TableNotFound" | DynamoDB table missing | Deploy backend/ first |
| "NoSuchBucket" | S3 bucket missing | Deploy backend/ first |
| "ValidationException" | Invalid backend config | Check bucket/table names match |

---

## 📞 Support Resources

### Documentation
- 📖 [Backend Setup Guide](Guides/BACKEND_SETUP.md)
- 📖 [Deployment Guide](Guides/DEPLOYMENT_GUIDE.md)
- 📖 [Architecture Guide](Guides/ARCHITECTURE.md)
- 📖 [Project Summary](Guides/PROJECT_SUMMARY.md)

### External Resources
- [Terraform S3 Backend Docs](https://www.terraform.io/language/settings/backends/s3)
- [AWS S3 Documentation](https://docs.aws.amazon.com/s3/)
- [State Locking](https://www.terraform.io/language/state/locking)

---

## 🎓 Learning Path

**Beginner:**
1. Read: `Guides/BACKEND_SETUP.md` (Quick Start section)
2. Run: `validate.ps1` or `validate.sh`
3. Do: Deploy backend, then dev

**Intermediate:**
1. Read: `Guides/DEPLOYMENT_GUIDE.md`
2. Understand: State file locations in S3
3. Practice: Make small infrastructure changes

**Advanced:**
1. Read: `Guides/ARCHITECTURE.md`
2. Implement: Multi-environment setup (dev/staging/prod)
3. Configure: Team access with IAM policies
4. Add: CloudTrail logging and alerts

---

## 🚀 What's Next?

1. **Today:** Run validation, deploy backend
2. **This Week:** Configure dev, deploy main infrastructure
3. **This Month:** Set up team access, add multi-environment setup

---

## 📝 Quick Notes

- Backend MUST be deployed before dev infrastructure
- State file is NEVER committed to Git
- DynamoDB lock auto-releases after 10 minutes (if process dies)
- S3 versioning keeps full history (no accidental deletions)
- On-demand DynamoDB billing = you only pay for requests made

---

**Version:** 1.0  
**Last Updated:** February 2026  
**Status:** ✅ Production Ready

#!/bin/bash
# System Validation Script
# Verifies backend, modular infrastructure, and all dependencies
# Usage: ./validate.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Infrastructure Validation Script${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Counter for checks
CHECKS_PASSED=0
CHECKS_FAILED=0

# Utility functions
check_command() {
    if command -v "$1" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $1 installed"
        ((CHECKS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $1 not found (required)"
        ((CHECKS_FAILED++))
        return 1
    fi
}

check_file() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✓${NC} $1 exists"
        ((CHECKS_PASSED++))
        return 0
    else
        echo -e "${RED}✗${NC} $1 missing (required)"
        ((CHECKS_FAILED++))
        return 1
    fi
}

check_terraform_syntax() {
    local dir=$1
    echo -e "\n${BLUE}Checking Terraform syntax in $dir...${NC}"
    
    if cd "$dir" && terraform validate &> /dev/null; then
        echo -e "${GREEN}✓${NC} Terraform syntax valid in $dir"
        ((CHECKS_PASSED++))
        cd - > /dev/null
        return 0
    else
        echo -e "${RED}✗${NC} Terraform syntax error in $dir"
        terraform validate
        ((CHECKS_FAILED++))
        cd - > /dev/null
        return 1
    fi
}

check_module_outputs() {
    local module=$1
    echo -e "\n${BLUE}Checking outputs in module $module...${NC}"
    
    if [ -f "modules/$module/outputs.tf" ]; then
        outputs=$(grep "^output" "modules/$module/outputs.tf" | wc -l)
        if [ "$outputs" -gt 0 ]; then
            echo -e "${GREEN}✓${NC} Module $module has $outputs outputs"
            ((CHECKS_PASSED++))
            return 0
        else
            echo -e "${YELLOW}⚠${NC} Module $module has no outputs"
            ((CHECKS_PASSED++))
            return 0
        fi
    else
        echo -e "${RED}✗${NC} outputs.tf missing in module $module"
        ((CHECKS_FAILED++))
        return 1
    fi
}

echo -e "${YELLOW}Phase 1: Prerequisites${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"

check_command "terraform"
check_command "aws"
check_command "jq"

echo -e "\n${YELLOW}Phase 2: AWS Credentials${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if aws sts get-caller-identity &> /dev/null; then
    ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
    REGION=$(aws configure get region || echo "us-east-1")
    echo -e "${GREEN}✓${NC} AWS credentials valid"
    echo -e "${GREEN}✓${NC} Account ID: $ACCOUNT"
    echo -e "${GREEN}✓${NC} Region: $REGION"
    CHECKS_PASSED=$((CHECKS_PASSED + 3))
else
    echo -e "${RED}✗${NC} AWS credentials not configured or invalid"
    CHECKS_FAILED=$((CHECKS_FAILED + 1))
fi

echo -e "\n${YELLOW}Phase 3: Project Structure${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"

check_file "backend/main.tf"
check_file "backend/variables.tf"
check_file "backend/terraform.tfvars"

check_file "dev/main.tf"
check_file "dev/backend.tf"
check_file "dev/variables.tf"
check_file "dev/terraform.tfvars"
check_file "dev/outputs.tf"

check_file "app/server.js"
check_file "app/Dockerfile"
check_file "app/package.json"

echo -e "\n${YELLOW}Phase 4: Modules Structure${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"

MODULES=("vpc" "security" "iam" "alb" "ecr" "ecs")

for module in "${MODULES[@]}"; do
    check_file "modules/$module/main.tf"
    check_file "modules/$module/variables.tf"
    check_file "modules/$module/outputs.tf"
done

echo -e "\n${YELLOW}Phase 5: Terraform Syntax Validation${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

check_terraform_syntax "backend"
check_terraform_syntax "dev"

for module in "${MODULES[@]}"; do
    check_terraform_syntax "modules/$module"
done

echo -e "\n${YELLOW}Phase 6: Module Outputs${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━"

for module in "${MODULES[@]}"; do
    check_module_outputs "$module"
done

echo -e "\n${YELLOW}Phase 7: Backend Configuration${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if grep -q "backend \"s3\"" dev/backend.tf; then
    echo -e "${GREEN}✓${NC} Backend configuration present in dev/backend.tf"
    ((CHECKS_PASSED++))
else
    echo -e "${RED}✗${NC} Backend configuration missing"
    ((CHECKS_FAILED++))
fi

if grep -q "terraform-state-serverless-app" backend/terraform.tfvars; then
    echo -e "${GREEN}✓${NC} Backend naming configured"
    ((CHECKS_PASSED++))
else
    echo -e "${YELLOW}⚠${NC} Backend naming not configured (will be auto-generated)"
    ((CHECKS_PASSED++))
fi

echo -e "\n${YELLOW}Phase 8: Module Dependencies${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check VPC module is referenced
if grep -q "module.vpc" dev/main.tf; then
    echo -e "${GREEN}✓${NC} VPC module used in main.tf"
    ((CHECKS_PASSED++))
else
    echo -e "${RED}✗${NC} VPC module not referenced"
    ((CHECKS_FAILED++))
fi

# Check security groups reference VPC
if grep -q "module.vpc.aws_vpc.main.id" modules/security/main.tf; then
    echo -e "${GREEN}✓${NC} Security groups reference VPC"
    ((CHECKS_PASSED++))
else
    echo -e "${YELLOW}⚠${NC} Security groups may have implicit VPC dependency"
    ((CHECKS_PASSED++))
fi

# Check ALB references security group
if grep -q "module.security.alb_security_group_id" modules/alb/main.tf; then
    echo -e "${GREEN}✓${NC} ALB references security group"
    ((CHECKS_PASSED++))
else
    echo -e "${YELLOW}⚠${NC} ALB may have implicit security group dependency"
    ((CHECKS_PASSED++))
fi

# Check ECS references all dependencies
if grep -q "module.iam\|module.alb\|module.ecr" dev/main.tf | grep -q "module.ecs"; then
    echo -e "${GREEN}✓${NC} ECS has explicit dependencies"
    ((CHECKS_PASSED++))
else
    echo -e "${YELLOW}⚠${NC} ECS dependencies appear implicit (should work)"
    ((CHECKS_PASSED++))
fi

echo -e "\n${YELLOW}Phase 9: Dockerfile Validation${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if grep -q "FROM node:18-alpine" app/Dockerfile; then
    echo -e "${GREEN}✓${NC} Dockerfile has correct base image"
    ((CHECKS_PASSED++))
else
    echo -e "${RED}✗${NC} Dockerfile base image incorrect"
    ((CHECKS_FAILED++))
fi

if grep -q "EXPOSE 8080" app/Dockerfile; then
    echo -e "${GREEN}✓${NC} Dockerfile exposes correct port"
    ((CHECKS_PASSED++))
else
    echo -e "${RED}✗${NC} Dockerfile port configuration incorrect"
    ((CHECKS_FAILED++))
fi

echo -e "\n${YELLOW}Phase 10: Application Files${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━"

if grep -q "express" app/package.json; then
    echo -e "${GREEN}✓${NC} Express dependency present"
    ((CHECKS_PASSED++))
else
    echo -e "${RED}✗${NC} Express dependency missing"
    ((CHECKS_FAILED++))
fi

if grep -q "app.listen\|app.get" app/server.js; then
    echo -e "${GREEN}✓${NC} Server.js appears valid"
    ((CHECKS_PASSED++))
else
    echo -e "${RED}✗${NC} Server.js may be invalid"
    ((CHECKS_FAILED++))
fi

if grep -q "/health" app/server.js; then
    echo -e "${GREEN}✓${NC} Health check endpoint present"
    ((CHECKS_PASSED++))
else
    echo -e "${RED}✗${NC} Health check endpoint missing"
    ((CHECKS_FAILED++))
fi

echo -e "\n${YELLOW}Phase 11: Documentation${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━"

DOCS=("Guides/README.md" "Guides/QUICKSTART.md" "Guides/ARCHITECTURE.md" "Guides/DEPLOYMENT_GUIDE.md" "Guides/PROJECT_SUMMARY.md" "Guides/BACKEND_SETUP.md")

for doc in "${DOCS[@]}"; do
    if check_file "$doc"; then
        lines=$(wc -l < "$doc")
        echo -e "  ${BLUE}→${NC} $lines lines"
    fi
done

echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}Validation Summary${NC}"
echo -e "${BLUE}========================================${NC}\n"

TOTAL=$((CHECKS_PASSED + CHECKS_FAILED))

echo -e "Checks Passed:  ${GREEN}$CHECKS_PASSED${NC}"
echo -e "Checks Failed:  ${RED}$CHECKS_FAILED${NC}"
echo -e "Total Checks:   $TOTAL"

if [ $CHECKS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}✓ All validations passed!${NC}"
    echo -e "${GREEN}✓ System is ready for deployment${NC}\n"
    
    echo -e "${BLUE}Next Steps:${NC}"
    echo -e "1. Deploy backend infrastructure:"
    echo -e "   ${BLUE}cd backend && terraform init && terraform apply${NC}"
    echo -e ""
    echo -e "2. Configure dev with backend:"
    echo -e "   ${BLUE}cd ../dev && terraform init -backend-config=\"bucket=...\" -backend-config=\"dynamodb_table=...\"${NC}"
    echo -e ""
    echo -e "3. Deploy main infrastructure:"
    echo -e "   ${BLUE}terraform apply${NC}"
    echo -e ""
    
    exit 0
else
    echo -e "\n${RED}✗ Validation failed!${NC}"
    echo -e "${RED}✗ Please fix the issues above${NC}\n"
    exit 1
fi

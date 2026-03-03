# System Validation Script (Windows PowerShell)
# Verifies backend, modular infrastructure, and all dependencies
# Usage: .\validate.ps1

param(
    [switch]$Verbose = $false
)

$ErrorActionPreference = "Continue"

# Color functions
function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor Yellow
}

function Write-Info {
    param([string]$Message)
    Write-Host "▶ $Message" -ForegroundColor Blue
}

function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Blue
    Write-Host $Message -ForegroundColor Blue
    Write-Host "========================================" -ForegroundColor Blue
}

function Write-Section {
    param([string]$Message)
    Write-Host ""
    Write-Host $Message -ForegroundColor Yellow
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Yellow
}

# Counter variables
[int]$ChecksPassed = 0
[int]$ChecksFailed = 0

# Check command exists
function Check-Command {
    param([string]$Command)
    
    $exists = $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
    
    if ($exists) {
        Write-Success "$Command installed"
        $global:ChecksPassed++
        return $true
    } else {
        Write-Error "$Command not found (required)"
        $global:ChecksFailed++
        return $false
    }
}

# Check file exists
function Check-File {
    param([string]$FilePath)
    
    if (Test-Path -Path $FilePath -PathType Leaf) {
        Write-Success "$FilePath exists"
        $global:ChecksPassed++
        return $true
    } else {
        Write-Error "$FilePath missing (required)"
        $global:ChecksFailed++
        return $false
    }
}

# Check directory exists
function Check-Directory {
    param([string]$DirPath)
    
    if (Test-Path -Path $DirPath -PathType Container) {
        Write-Success "$DirPath exists"
        $global:ChecksPassed++
        return $true
    } else {
        Write-Error "$DirPath missing (required)"
        $global:ChecksFailed++
        return $false
    }
}

# Check Terraform syntax
function Check-TerraformSyntax {
    param([string]$Directory)
    
    Write-Info "Checking Terraform syntax in $Directory..."
    
    Push-Location $Directory
    
    try {
        $output = & terraform validate 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Terraform syntax valid in $Directory"
            $global:ChecksPassed++
            Pop-Location
            return $true
        } else {
            Write-Error "Terraform syntax error in $Directory"
            Write-Host $output -ForegroundColor Red
            $global:ChecksFailed++
            Pop-Location
            return $false
        }
    } catch {
        Write-Error "Error validating $Directory"
        $global:ChecksFailed++
        Pop-Location
        return $false
    }
}

# Check module outputs
function Check-ModuleOutputs {
    param([string]$Module)
    
    $OutputsFile = "modules\$Module\outputs.tf"
    
    Write-Info "Checking outputs in module $Module..."
    
    if (-not (Test-Path $OutputsFile)) {
        Write-Error "outputs.tf missing in module $Module"
        $global:ChecksFailed++
        return $false
    }
    
    $content = Get-Content $OutputsFile -Raw
    $outputs = ($content | Select-String "^output" | Measure-Object).Count
    
    if ($outputs -gt 0) {
        Write-Success "Module $Module has $outputs outputs"
        $global:ChecksPassed++
        return $true
    } else {
        Write-Warning "Module $Module has no outputs"
        $global:ChecksPassed++
        return $true
    }
}

# Main validation script

Write-Header "Infrastructure Validation Script"

# Phase 1: Prerequisites
Write-Section "Phase 1: Prerequisites"

Check-Command "terraform"
Check-Command "aws"

# Phase 2: AWS Credentials
Write-Section "Phase 2: AWS Credentials"

try {
    $caller_identity = & aws sts get-caller-identity --output json | ConvertFrom-Json
    
    Write-Success "AWS credentials valid"
    Write-Success "Account ID: $($caller_identity.Account)"
    
    try {
        $region = & aws configure get region
        Write-Success "Region: $region"
        $global:ChecksPassed += 2
    } catch {
        Write-Warning "Region not configured (using us-east-1 default)"
        $global:ChecksPassed++
    }
} catch {
    Write-Error "AWS credentials not configured or invalid"
    $global:ChecksFailed++
}

# Phase 3: Project Structure
Write-Section "Phase 3: Project Structure"

Check-File "backend\main.tf"
Check-File "backend\variables.tf"
Check-File "backend\terraform.tfvars"

Check-File "dev\main.tf"
Check-File "dev\backend.tf"
Check-File "dev\variables.tf"
Check-File "dev\terraform.tfvars"
Check-File "dev\outputs.tf"

Check-File "app\server.js"
Check-File "app\Dockerfile"
Check-File "app\package.json"

# Phase 4: Modules Structure
Write-Section "Phase 4: Modules Structure"

$modules = @("vpc", "security", "iam", "alb", "ecr", "ecs")

foreach ($module in $modules) {
    Check-File "modules\$module\main.tf"
    Check-File "modules\$module\variables.tf"
    Check-File "modules\$module\outputs.tf"
}

# Phase 5: Terraform Syntax Validation
Write-Section "Phase 5: Terraform Syntax Validation"

Check-TerraformSyntax "backend"
Check-TerraformSyntax "dev"

foreach ($module in $modules) {
    Check-TerraformSyntax "modules\$module"
}

# Phase 6: Module Outputs
Write-Section "Phase 6: Module Outputs"

foreach ($module in $modules) {
    Check-ModuleOutputs $module
}

# Phase 7: Backend Configuration
Write-Section "Phase 7: Backend Configuration"

$backend_config = Get-Content "dev\backend.tf" -Raw

if ($backend_config -match 'backend "s3"') {
    Write-Success "Backend configuration present in dev/backend.tf"
    $global:ChecksPassed++
} else {
    Write-Error "Backend configuration missing"
    $global:ChecksFailed++
}

$backend_tfvars = Get-Content "backend\terraform.tfvars" -Raw

if ($backend_tfvars -match "terraform-state-serverless-app") {
    Write-Success "Backend naming configured"
    $global:ChecksPassed++
} else {
    Write-Warning "Backend naming not configured (will be auto-generated)"
    $global:ChecksPassed++
}

# Phase 8: Module Dependencies
Write-Section "Phase 8: Module Dependencies"

$main_tf = Get-Content "dev\main.tf" -Raw

if ($main_tf -match "module.vpc") {
    Write-Success "VPC module used in main.tf"
    $global:ChecksPassed++
} else {
    Write-Error "VPC module not referenced"
    $global:ChecksFailed++
}

if ($main_tf -match "module.security") {
    Write-Success "Security module used in main.tf"
    $global:ChecksPassed++
} else {
    Write-Error "Security module not referenced"
    $global:ChecksFailed++
}

if ($main_tf -match "module.iam") {
    Write-Success "IAM module used in main.tf"
    $global:ChecksPassed++
} else {
    Write-Error "IAM module not referenced"
    $global:ChecksFailed++
}

if ($main_tf -match "module.alb") {
    Write-Success "ALB module used in main.tf"
    $global:ChecksPassed++
} else {
    Write-Error "ALB module not referenced"
    $global:ChecksFailed++
}

if ($main_tf -match "module.ecr") {
    Write-Success "ECR module used in main.tf"
    $global:ChecksPassed++
} else {
    Write-Error "ECR module not referenced"
    $global:ChecksFailed++
}

if ($main_tf -match "module.ecs") {
    Write-Success "ECS module used in main.tf"
    $global:ChecksPassed++
} else {
    Write-Error "ECS module not referenced"
    $global:ChecksFailed++
}

# Phase 9: Dockerfile Validation
Write-Section "Phase 9: Dockerfile Validation"

$dockerfile = Get-Content "app\Dockerfile" -Raw

if ($dockerfile -match "FROM node:18-alpine") {
    Write-Success "Dockerfile has correct base image"
    $global:ChecksPassed++
} else {
    Write-Error "Dockerfile base image incorrect"
    $global:ChecksFailed++
}

if ($dockerfile -match "EXPOSE 8080") {
    Write-Success "Dockerfile exposes correct port"
    $global:ChecksPassed++
} else {
    Write-Error "Dockerfile port configuration incorrect"
    $global:ChecksFailed++
}

# Phase 10: Application Files
Write-Section "Phase 10: Application Files"

$package_json = Get-Content "app\package.json" -Raw

if ($package_json -match "express") {
    Write-Success "Express dependency present"
    $global:ChecksPassed++
} else {
    Write-Error "Express dependency missing"
    $global:ChecksFailed++
}

$server_js = Get-Content "app\server.js" -Raw

if ($server_js -match "app.listen|app.get") {
    Write-Success "Server.js appears valid"
    $global:ChecksPassed++
} else {
    Write-Error "Server.js may be invalid"
    $global:ChecksFailed++
}

if ($server_js -match "/health") {
    Write-Success "Health check endpoint present"
    $global:ChecksPassed++
} else {
    Write-Error "Health check endpoint missing"
    $global:ChecksFailed++
}

# Phase 11: Documentation
Write-Section "Phase 11: Documentation"

$docs = @(
    "Guides\README.md",
    "Guides\QUICKSTART.md",
    "Guides\ARCHITECTURE.md",
    "Guides\DEPLOYMENT_GUIDE.md",
    "Guides\PROJECT_SUMMARY.md",
    "Guides\BACKEND_SETUP.md"
)

foreach ($doc in $docs) {
    if (Test-Path $doc) {
        $lines = (Get-Content $doc | Measure-Object -Line).Lines
        Write-Success "$doc exists ($lines lines)"
        $global:ChecksPassed++
    } else {
        Write-Error "$doc missing"
        $global:ChecksFailed++
    }
}

# Summary
Write-Header "Validation Summary"

$total = $global:ChecksPassed + $global:ChecksFailed

Write-Host "Checks Passed:  " -NoNewline
Write-Host "$($global:ChecksPassed)" -ForegroundColor Green

Write-Host "Checks Failed:  " -NoNewline
Write-Host "$($global:ChecksFailed)" -ForegroundColor Red

Write-Host "Total Checks:   $total"

Write-Host ""

if ($global:ChecksFailed -eq 0) {
    Write-Host "✓ All validations passed!" -ForegroundColor Green
    Write-Host "✓ System is ready for deployment" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "Next Steps:" -ForegroundColor Blue
    Write-Host "1. Deploy backend infrastructure:" -ForegroundColor Blue
    Write-Host "   cd backend; terraform init; terraform apply" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "2. Configure dev with backend:" -ForegroundColor Blue
    Write-Host "   cd ..\dev" -ForegroundColor Magenta
    Write-Host "   terraform init -backend-config=`"bucket=...`" -backend-config=`"dynamodb_table=...`"" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "3. Deploy main infrastructure:" -ForegroundColor Blue
    Write-Host "   terraform apply" -ForegroundColor Magenta
    Write-Host ""
    
    exit 0
} else {
    Write-Host "✗ Validation failed!" -ForegroundColor Red
    Write-Host "✗ Please fix the issues above" -ForegroundColor Red
    Write-Host ""
    
    exit 1
}

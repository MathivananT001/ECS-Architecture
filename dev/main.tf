terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC Module
module "vpc" {
  source = "../modules/vpc"

  app_name              = var.app_name
  vpc_cidr              = var.vpc_cidr
  public_subnet_cidr    = var.public_subnet_cidr
  private_subnet_cidr   = var.private_subnet_cidr
  availability_zone     = var.availability_zone
  tags                  = var.tags
}

# Security Module
module "security" {
  source = "../modules/security"

  app_name           = var.app_name
  vpc_id             = module.vpc.vpc_id
  container_port     = var.container_port
  tags               = var.tags
}

# IAM Module
module "iam" {
  source = "../modules/iam"

  app_name = var.app_name
  tags     = var.tags
}

# ALB Module
module "alb" {
  source = "../modules/alb"

  app_name               = var.app_name
  vpc_id                 = module.vpc.vpc_id
  public_subnet_id       = module.vpc.public_subnet_id
  alb_security_group_id  = module.security.alb_security_group_id
  container_port         = var.container_port
  tags                   = var.tags
}

# ECR Module
module "ecr" {
  source = "../modules/ecr"

  app_name = var.app_name
  tags     = var.tags
}

# ECS Module
module "ecs" {
  source = "../modules/ecs"

  app_name                     = var.app_name
  aws_region                   = var.aws_region
  private_subnet_id            = module.vpc.private_subnet_id
  ecs_security_group_id        = module.security.ecs_security_group_id
  ecs_task_execution_role_arn  = module.iam.ecs_task_execution_role_arn
  ecs_task_role_arn            = module.iam.ecs_task_role_arn
  target_group_arn             = module.alb.target_group_arn
  alb_listener_http_arn        = module.alb.alb_arn
  container_port               = var.container_port
  container_image              = var.container_image
  task_cpu                     = var.task_cpu
  task_memory                  = var.task_memory
  desired_count                = var.desired_count
  tags                         = var.tags

  depends_on = [module.alb]
}

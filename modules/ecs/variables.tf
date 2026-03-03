variable "app_name" {
  description = "Application name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "private_subnet_id" {
  description = "Private subnet ID"
  type        = string
}

variable "ecs_security_group_id" {
  description = "ECS security group ID"
  type        = string
}

variable "ecs_task_execution_role_arn" {
  description = "ECS task execution role ARN"
  type        = string
}

variable "ecs_task_role_arn" {
  description = "ECS task role ARN"
  type        = string
}

variable "target_group_arn" {
  description = "Target group ARN"
  type        = string
}

variable "alb_listener_http_arn" {
  description = "ALB HTTP listener ARN"
  type        = string
}

variable "container_port" {
  description = "Container port"
  type        = number
}

variable "container_image" {
  description = "Docker image URI"
  type        = string
}

variable "task_cpu" {
  description = "Task CPU units"
  type        = number
}

variable "task_memory" {
  description = "Task memory in MB"
  type        = number
}

variable "desired_count" {
  description = "Desired number of running tasks"
  type        = number
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
}

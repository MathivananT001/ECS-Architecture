variable "app_name" {
  description = "Application name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "container_port" {
  description = "Container port"
  type        = number
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
}

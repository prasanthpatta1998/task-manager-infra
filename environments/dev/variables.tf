variable "aws_region" {
  description = "AWS region."
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Name prefix used for resources."
  type        = string
  default     = "task-manager"
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "VPC IPv4 CIDR."
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDRs for the two public subnets."
  type        = list(string)
  default     = ["10.20.1.0/24", "10.20.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs for the two private subnets."
  type        = list(string)
  default     = ["10.20.11.0/24", "10.20.12.0/24"]
}

variable "api_image" {
  description = "Fully qualified container image URI for the API."
  type        = string
}

variable "mongodb_uri_secret_arn" {
  description = "Secrets Manager ARN for the MONGODB_URI JSON key, including the :MONGODB_URI:: selector."
  type        = string
}

variable "api_container_port" {
  description = "Port the API container listens on."
  type        = number
  default     = 4000
}

variable "api_cpu" {
  description = "Fargate task CPU units."
  type        = number
  default     = 256
}

variable "api_memory" {
  description = "Fargate task memory in MiB."
  type        = number
  default     = 512
}

variable "api_desired_count" {
  description = "Desired ECS service task count."
  type        = number
  default     = 1
}

variable "health_check_path" {
  description = "HTTP health check path served by the API."
  type        = string
  default     = "/health"
}

variable "frontend_price_class" {
  description = "CloudFront price class."
  type        = string
  default     = "PriceClass_100"
}

variable "alarm_email" {
  description = "Optional email address for CloudWatch alarm notifications. Leave empty to skip SNS."
  type        = string
  default     = ""
}

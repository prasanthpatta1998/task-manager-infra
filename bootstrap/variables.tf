variable "aws_region" {
  description = "AWS region for the Terraform state bucket."
  type        = string
  default     = "ap-south-1"
}

variable "state_bucket_prefix" {
  description = "Prefix for the globally unique state bucket name."
  type        = string
  default     = "task-manager-tfstate"
}

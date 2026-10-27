variable "name" { type = string }
variable "aws_region" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "vpc_id" { type = string }
variable "alb_security_group_id" { type = string }
variable "target_group_arn" { type = string }
variable "image" { type = string }
variable "container_port" { type = number }
variable "cpu" { type = number }
variable "memory" { type = number }
variable "desired_count" { type = number }
variable "mongodb_uri_secret_arn" {
  description = "Secrets Manager ARN for the JSON MONGODB_URI value, including the :MONGODB_URI:: selector required by ECS."
  type        = string

  validation {
    condition     = endswith(var.mongodb_uri_secret_arn, ":MONGODB_URI::")
    error_message = "mongodb_uri_secret_arn must end with :MONGODB_URI:: so ECS reads the MONGODB_URI key from the secret."
  }
}

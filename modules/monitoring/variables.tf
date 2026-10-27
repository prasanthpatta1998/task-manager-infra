variable "name" { type = string }
variable "alb_arn_suffix" { type = string }
variable "ecs_cluster_name" { type = string }
variable "ecs_service_name" { type = string }
variable "alarm_email" {
  type    = string
  default = ""
}

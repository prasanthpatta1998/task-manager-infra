output "api_base_url" { value = "http://${aws_lb.this.dns_name}" }
output "alb_security_group_id" { value = aws_security_group.alb.id }
output "target_group_arn" { value = aws_lb_target_group.api.arn }
output "alb_arn_suffix" { value = aws_lb.this.arn_suffix }

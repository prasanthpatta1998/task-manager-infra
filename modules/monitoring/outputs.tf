output "alarm_topic_arn" {
  value       = try(aws_sns_topic.alarms[0].arn, null)
  description = "SNS topic ARN when alarm_email is configured."
}

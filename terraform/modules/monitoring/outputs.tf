output "sns_topic_arn" {
  description = "ARN of the SNS alarm topic"
  value       = aws_sns_topic.alarms.arn
}

output "log_group_name" {
  description = "Name of the application log group"
  value       = aws_cloudwatch_log_group.app.name
}

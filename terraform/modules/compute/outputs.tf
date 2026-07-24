output "alb_dns_name" {
  description = "Public DNS name of the ALB"
  value       = aws_lb.main.dns_name
}

output "alb_arn_suffix" {
  description = "ARN suffix of the ALB, used for CloudWatch alarms"
  value       = aws_lb.main.arn_suffix
}

output "target_group_arn_suffix" {
  description = "ARN suffix of the target group, used for CloudWatch alarms"
  value       = aws_lb_target_group.app.arn_suffix
}

output "ec2_security_group_id" {
  description = "Security group ID of the EC2 app instances — RDS ingress is scoped to this"
  value       = aws_security_group.ec2.id
}

output "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.app.name
}

output "launch_template_id" {
  description = "ID of the Launch Template"
  value       = aws_launch_template.app.id
}

output "log_group_name" {
  description = "CloudWatch Logs group name the app writes to"
  value       = "/${var.project_name}/${var.environment}/app"
}

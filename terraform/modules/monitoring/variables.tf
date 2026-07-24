variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod)"
  type        = string
}

variable "log_group_name" {
  description = "CloudWatch Logs group name the app/CloudWatch Agent writes to"
  type        = string
}

variable "log_retention_days" {
  description = "Retention period for application logs"
  type        = number
  default     = 14
}

variable "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group to monitor"
  type        = string
}

variable "alb_arn_suffix" {
  description = "ARN suffix of the ALB (for ALB-level metrics)"
  type        = string
}

variable "target_group_arn_suffix" {
  description = "ARN suffix of the target group (for healthy-host metrics)"
  type        = string
}

variable "alarm_email" {
  description = "Email address to subscribe to the SNS alarm topic"
  type        = string
}

variable "tags" {
  description = "Common tags applied to all resources in this module"
  type        = map(string)
  default     = {}
}

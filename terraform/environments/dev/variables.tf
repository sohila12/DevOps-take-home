variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "devops-takehome"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "azs" {
  description = "Availability zones to use"
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b"]
}

variable "github_repo" {
  description = "GitHub repo allowed to assume the CI/CD deploy role, as \"org/repo\""
  type        = string
}

variable "alarm_email" {
  description = "Email address for CloudWatch alarm notifications"
  type        = string
}

variable "app_port" {
  description = "Port the Flask app listens on inside the container"
  type        = number
  default     = 5000
}

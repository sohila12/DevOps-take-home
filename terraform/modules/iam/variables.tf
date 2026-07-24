variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod)"
  type        = string
}

variable "ecr_repository_arn" {
  description = "ARN of the ECR repository the EC2 role needs pull access to"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository allowed to assume the CI/CD role, in the form \"org/repo\""
  type        = string
}

variable "github_branch" {
  description = "Git branch allowed to assume the CI/CD deploy role via OIDC"
  type        = string
  default     = "main"
}

variable "tags" {
  description = "Common tags applied to all resources in this module"
  type        = map(string)
  default     = {}
}

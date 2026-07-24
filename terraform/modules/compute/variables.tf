variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID to deploy compute resources into"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the ALB"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the EC2 instances"
  type        = list(string)
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "iam_instance_profile_name" {
  description = "IAM instance profile name to attach to the Launch Template"
  type        = string
}

variable "ecr_repository_url" {
  description = "ECR repository URL the instance will pull the app image from"
  type        = string
}

variable "app_port" {
  description = "Port the containerized application listens on"
  type        = number
  default     = 5000
}

variable "min_size" {
  description = "ASG minimum size"
  type        = number
  default     = 1
}

variable "desired_capacity" {
  description = "ASG desired capacity"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "ASG maximum size"
  type        = number
  default     = 2
}

variable "health_check_path" {
  description = "HTTP path the ALB target group uses for health checks"
  type        = string
  default     = "/health"
}

variable "image_tag" {
  description = "Docker image tag to deploy (Git SHA from CI, or \"latest\")"
  type        = string
  default     = "latest"
}

variable "tags" {
  description = "Common tags applied to all resources in this module"
  type        = map(string)
  default     = {}
}

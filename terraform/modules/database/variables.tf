variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "Deployment environment (e.g. dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID to deploy the database into"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the DB subnet group (must span 2 AZs)"
  type        = list(string)
}

variable "ec2_security_group_id" {
  description = "Security group ID of the EC2 instances — the only allowed source for DB traffic"
  type        = string
}

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Master username for the database"
  type        = string
  default     = "appadmin"
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "engine_version" {
  description = "PostgreSQL engine version. Leave null to auto-select the latest version available in the target region/account (avoids hardcoding a version that may not exist everywhere or may age out)."
  type        = string
  default     = null
}

variable "multi_az" {
  description = "Whether to deploy a Multi-AZ standby (off by default to keep this assessment low-cost; see README for prod recommendation)"
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 1
}

variable "skip_final_snapshot" {
  description = "Skip final snapshot on destroy — true here since this is a disposable assessment environment"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags applied to all resources in this module"
  type        = map(string)
  default     = {}
}

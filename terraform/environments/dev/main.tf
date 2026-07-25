locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# =============================================================================
# ECR repository — created at root because both the iam module (pull/push
# policies) and the compute module (image URL) need it, and neither should
# own the other's dependency.
# =============================================================================
resource "aws_ecr_repository" "app" {
  name                 = "${var.project_name}-${var.environment}-app"
  image_tag_mutability = "MUTABLE" # the pipeline intentionally overwrites the floating "latest" tag on every push, per the assessment's dual-tagging requirement (latest + Git SHA) -- IMMUTABLE blocks that after the very first push. SHA tags stay unique in practice since each Git commit SHA is only ever pushed once.
  force_delete = true # allows `terraform destroy` to remove the repo even if
                       # it still has images — appropriate for this disposable
                       # dev environment; drop this in a prod environment
                       # where accidental repo deletion should require an
                       # explicit, separate confirmation step.

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = local.common_tags
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}

# =============================================================================
# Networking
# =============================================================================
module "networking" {
  source = "../../modules/networking"

  project_name = var.project_name
  environment  = var.environment
  azs          = var.azs
  tags         = local.common_tags
}

# =============================================================================
# IAM (needs the ECR repo ARN for scoped pull/push policies)
# =============================================================================
module "iam" {
  source = "../../modules/iam"

  project_name       = var.project_name
  environment        = var.environment
  ecr_repository_arn = aws_ecr_repository.app.arn
  github_repo        = var.github_repo
  tags               = local.common_tags
}

# =============================================================================
# Compute (ALB, ASG, Launch Template) — needs networking + iam + ECR
# =============================================================================
module "compute" {
  source = "../../modules/compute"

  project_name              = var.project_name
  environment               = var.environment
  vpc_id                    = module.networking.vpc_id
  public_subnet_ids         = module.networking.public_subnet_ids
  private_subnet_ids        = module.networking.private_subnet_ids
  iam_instance_profile_name = module.iam.ec2_instance_profile_name
  ecr_repository_url        = aws_ecr_repository.app.repository_url
  app_port                  = var.app_port
  tags                      = local.common_tags
}

# =============================================================================
# Database — needs networking + compute's EC2 security group id
# =============================================================================
module "database" {
  source = "../../modules/database"

  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.networking.vpc_id
  private_subnet_ids    = module.networking.private_subnet_ids
  ec2_security_group_id = module.compute.ec2_security_group_id
  tags                  = local.common_tags
}

# =============================================================================
# Monitoring — needs compute's ASG/ALB/target group identifiers
# =============================================================================
module "monitoring" {
  source = "../../modules/monitoring"

  project_name            = var.project_name
  environment             = var.environment
  log_group_name          = module.compute.log_group_name
  autoscaling_group_name  = module.compute.autoscaling_group_name
  alb_arn_suffix          = module.compute.alb_arn_suffix
  target_group_arn_suffix = module.compute.target_group_arn_suffix
  alarm_email             = var.alarm_email
  tags                    = local.common_tags
}

# =============================================================================
# Frontend — standalone, no dependencies on the other modules
# =============================================================================
module "frontend" {
  source = "../../modules/frontend"

  project_name = var.project_name
  environment  = var.environment
  tags         = local.common_tags
}

# =============================================================================
# Cross-cutting: grant the EC2 role read access to exactly the DB secret.
# Attached here (not inside the iam module) to avoid an iam<->database
# module cycle — this resource only depends on outputs, not the other way
# around, so it's safe to create last.
# =============================================================================
data "aws_iam_policy_document" "ec2_read_db_secret" {
  statement {
    sid       = "ReadDbSecret"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [module.database.db_secret_arn]
  }
}

resource "aws_iam_role_policy" "ec2_read_db_secret" {
  name   = "${var.project_name}-${var.environment}-ec2-read-db-secret"
  role   = module.iam.ec2_role_name
  policy = data.aws_iam_policy_document.ec2_read_db_secret.json
}

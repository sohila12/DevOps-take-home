locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ---------------------------------------------------------------------------
# Auto-discover the latest available PostgreSQL engine version if one wasn't
# pinned via var.engine_version. Avoids hardcoding a specific version number
# that may not be offered in every region/account, or that ages out over time.
# ---------------------------------------------------------------------------
data "aws_rds_engine_version" "postgres" {
  engine = "postgres"
  latest = true
}

# ---------------------------------------------------------------------------
# DB subnet group — private subnets only, spans both AZs
# ---------------------------------------------------------------------------
resource "aws_db_subnet_group" "main" {
  name       = "${local.name_prefix}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-db-subnet-group"
  })
}

# ---------------------------------------------------------------------------
# Security group — only the EC2 app security group may reach Postgres
# ---------------------------------------------------------------------------
resource "aws_security_group" "rds" {
  name_prefix = "${local.name_prefix}-rds-"
  description = "Allow Postgres from the app tier only"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-rds-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "rds_ingress_from_ec2" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = var.ec2_security_group_id
  description              = "Postgres from EC2 app instances"
}

resource "aws_security_group_rule" "rds_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.rds.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound (patching, etc.)"
}

# ---------------------------------------------------------------------------
# RDS PostgreSQL instance
#   - Encryption at rest enabled (KMS default key)
#   - Not publicly accessible
#   - Master password managed by RDS itself and stored in Secrets Manager —
#     Terraform never sees or stores the plaintext password, and it never
#     lands in a GitHub secret or the app repo.
# ---------------------------------------------------------------------------
resource "aws_db_instance" "main" {
  identifier     = "${local.name_prefix}-db"
  engine         = "postgres"
  engine_version = coalesce(var.engine_version, data.aws_rds_engine_version.postgres.version)
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username

  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  multi_az                = var.multi_az
  backup_retention_period = var.backup_retention_period
  skip_final_snapshot     = var.skip_final_snapshot

  deletion_protection = false # would be true in a real prod environment

  tags = merge(var.tags, {
    Name = "${local.name_prefix}-db"
  })
}

# ---------------------------------------------------------------------------
# SSM Parameters — how the app discovers DB connection info at runtime.
# The instance role already has ssm:GetParameter scoped to this path prefix
# (see the iam module), so no new cross-module IAM dependency is needed here.
# The secret ARN itself is not sensitive; the *value* it points to is fetched
# separately from Secrets Manager using a role permission granted at root.
# ---------------------------------------------------------------------------
resource "aws_ssm_parameter" "db_host" {
  name  = "/${var.project_name}/${var.environment}/db/host"
  type  = "String"
  value = aws_db_instance.main.address
  tags  = var.tags
}

resource "aws_ssm_parameter" "db_name" {
  name  = "/${var.project_name}/${var.environment}/db/name"
  type  = "String"
  value = aws_db_instance.main.db_name
  tags  = var.tags
}

resource "aws_ssm_parameter" "db_secret_arn" {
  name  = "/${var.project_name}/${var.environment}/db/secret_arn"
  type  = "String"
  value = aws_db_instance.main.master_user_secret[0].secret_arn
  tags  = var.tags
}

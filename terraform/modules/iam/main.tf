locals {
  name_prefix  = "${var.project_name}-${var.environment}"
  github_owner = split("/", var.github_repo)[0]
  github_repo  = split("/", var.github_repo)[1]
}

# =============================================================================
# EC2 instance role
#   - SSM Session Manager (no SSH needed)
#   - Pull-only access to the specific ECR repo
#   - Push CloudWatch Logs + metrics (CloudWatch Agent)
# =============================================================================
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_instance_role" {
  name               = "${local.name_prefix}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
  tags               = var.tags
}

# AWS-managed policy that grants exactly what SSM Session Manager needs —
# this is what lets us drop SSH entirely.
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Scoped ECR pull policy — GetAuthorizationToken must be "*" (AWS requirement,
# the action isn't resource-scopable), everything else is locked to this repo.
data "aws_iam_policy_document" "ecr_pull" {
  statement {
    sid       = "ECRAuth"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "ECRPullFromRepo"
    effect = "Allow"
    actions = [
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchCheckLayerAvailability",
    ]
    resources = [var.ecr_repository_arn]
  }
}

resource "aws_iam_policy" "ecr_pull" {
  name   = "${local.name_prefix}-ecr-pull"
  policy = data.aws_iam_policy_document.ecr_pull.json
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "ecr_pull" {
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = aws_iam_policy.ecr_pull.arn
}

# CloudWatch Agent: logs + custom metrics, scoped to this app's log group prefix
data "aws_iam_policy_document" "cloudwatch_agent" {
  statement {
    sid    = "Logs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]
    resources = ["arn:aws:logs:*:*:log-group:/${var.project_name}/${var.environment}/*"]
  }

  statement {
    sid       = "Metrics"
    effect    = "Allow"
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "cloudwatch:namespace"
      values   = ["CWAgent"]
    }
  }

  statement {
    sid       = "SSMParamRead"
    effect    = "Allow"
    actions   = ["ssm:GetParameter"]
    resources = ["arn:aws:ssm:*:*:parameter/${var.project_name}/${var.environment}/*"]
  }
}

resource "aws_iam_policy" "cloudwatch_agent" {
  name   = "${local.name_prefix}-cloudwatch-agent"
  policy = data.aws_iam_policy_document.cloudwatch_agent.json
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.ec2_instance_role.name
  policy_arn = aws_iam_policy.cloudwatch_agent.arn
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "${local.name_prefix}-ec2-instance-profile"
  role = aws_iam_role.ec2_instance_role.name
  tags = var.tags
}

# =============================================================================
# GitHub Actions OIDC — lets the pipeline assume a role without any
# long-lived AWS access keys stored as GitHub secrets.
# =============================================================================
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
  tags            = var.tags
}

data "aws_iam_policy_document" "github_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Restricts which repo AND branch can assume this role — a fork or PR
    # branch cannot deploy to AWS.
    #
    # Matches two formats: the legacy "repo:owner/repo:ref:..." claim, and
    # GitHub's newer immutable "repo:owner@ownerID/repo@repoID:ref:..." claim
    # (rolled out July 15, 2026 for newly-created repos, embedding stable
    # numeric IDs so a renamed/recycled repo name can't forge a matching
    # token). Matching both means this trust policy works regardless of
    # which format a given repository actually uses.
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${local.github_owner}/${local.github_repo}:ref:refs/heads/${var.github_branch}",
        "repo:${local.github_owner}@*/${local.github_repo}@*:ref:refs/heads/${var.github_branch}",
      ]
    }
  }
}

resource "aws_iam_role" "github_deploy" {
  name               = "${local.name_prefix}-github-deploy-role"
  assume_role_policy = data.aws_iam_policy_document.github_assume_role.json
  tags               = var.tags
}

data "aws_iam_policy_document" "github_deploy_permissions" {
  statement {
    sid    = "ECRPushPull"
    effect = "Allow"
    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
    ]
    resources = [var.ecr_repository_arn]
  }

  statement {
    sid       = "ECRAuth"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # Describe/List actions don't support resource-level or tag-based
  # conditions in IAM — they're account/region-wide by design. Attaching
  # the Project-tag condition to them (as an earlier version of this policy
  # did) causes the condition to silently never match, which falls through
  # to an implicit deny even though the action is listed. Kept unconditional
  # here; scoped tightly instead by only granting exactly the 4 read actions
  # the pipeline needs.
  statement {
    sid    = "LaunchTemplateDescribe"
    effect = "Allow"
    actions = [
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeLaunchTemplateVersions",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "LaunchTemplateWrite"
    effect = "Allow"
    actions = [
      "ec2:CreateLaunchTemplateVersion",
      "ec2:ModifyLaunchTemplate",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Project"
      values   = [var.project_name]
    }
  }

  statement {
    sid    = "ASGDescribe"
    effect = "Allow"
    actions = [
      "autoscaling:DescribeInstanceRefreshes",
      "autoscaling:DescribeAutoScalingGroups",
    ]
    resources = ["*"]
  }

  # Associating a Launch Template with an ASG requires this separately from
  # autoscaling:UpdateAutoScalingGroup itself — AWS checks whether the caller
  # is authorized to "use" the specific launch template (since the ASG
  # service effectively launches instances using it on the caller's behalf).
  # Three permissions are needed together for this check to pass:
  #   - ec2:RunInstances itself
  #   - ec2:CreateTags, because the Launch Template's tag_specifications
  #     block tags instances on launch
  #   - iam:PassRole, because the Launch Template attaches an instance
  #     profile, and passing that role to EC2 requires explicit permission
  statement {
    sid       = "RunInstancesUsingLaunchTemplate"
    effect    = "Allow"
    actions   = ["ec2:RunInstances"]
    resources = ["*"]
  }

  statement {
    sid       = "CreateTagsOnLaunch"
    effect    = "Allow"
    actions   = ["ec2:CreateTags"]
    resources = ["arn:aws:ec2:*:*:*/*"]
    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"
      values   = ["RunInstances"]
    }
  }

  statement {
    sid       = "PassEC2InstanceRole"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.ec2_instance_role.arn]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ec2.amazonaws.com"]
    }
  }

  statement {
    sid    = "ASGWrite"
    effect = "Allow"
    actions = [
      "autoscaling:StartInstanceRefresh",
      "autoscaling:UpdateAutoScalingGroup",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Project"
      values   = [var.project_name]
    }
  }
}

resource "aws_iam_policy" "github_deploy_permissions" {
  name   = "${local.name_prefix}-github-deploy-permissions"
  policy = data.aws_iam_policy_document.github_deploy_permissions.json
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "github_deploy_permissions" {
  role       = aws_iam_role.github_deploy.name
  policy_arn = aws_iam_policy.github_deploy_permissions.arn
}

output "alb_dns_name" {
  description = "Public URL of the backend API"
  value       = "http://${module.compute.alb_dns_name}"
}

output "cloudfront_url" {
  description = "Public URL of the frontend"
  value       = "https://${module.frontend.cloudfront_domain_name}"
}

output "frontend_bucket_name" {
  description = "S3 bucket to sync the built frontend to"
  value       = module.frontend.bucket_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (for cache invalidation in CI)"
  value       = module.frontend.cloudfront_distribution_id
}

output "ecr_repository_url" {
  description = "ECR repository URL to push images to"
  value       = aws_ecr_repository.app.repository_url
}

output "db_endpoint" {
  description = "RDS Postgres endpoint"
  value       = module.database.db_endpoint
}

output "github_deploy_role_arn" {
  description = "Role ARN for the GitHub Actions workflow to assume via OIDC"
  value       = module.iam.github_deploy_role_arn
}

output "autoscaling_group_name" {
  description = "ASG name (for CI/CD instance refresh commands)"
  value       = module.compute.autoscaling_group_name
}

output "launch_template_id" {
  description = "Launch Template ID (for CI/CD new-version commands)"
  value       = module.compute.launch_template_id
}

output "ec2_instance_profile_name" {
  description = "Name of the instance profile to attach to the Launch Template"
  value       = aws_iam_instance_profile.ec2_instance_profile.name
}

output "ec2_role_arn" {
  description = "ARN of the EC2 instance role"
  value       = aws_iam_role.ec2_instance_role.arn
}

output "ec2_role_name" {
  description = "Name of the EC2 instance role — used at root to attach the DB-secret-read policy"
  value       = aws_iam_role.ec2_instance_role.name
}

output "github_deploy_role_arn" {
  description = "ARN of the role GitHub Actions assumes via OIDC — put this in a repo variable, not a secret"
  value       = aws_iam_role.github_deploy.arn
}

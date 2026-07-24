output "bucket_name" {
  description = "Name of the S3 bucket holding the frontend build"
  value       = aws_s3_bucket.frontend.id
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name — the public URL of the frontend"
  value       = aws_cloudfront_distribution.frontend.domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID — used by CI/CD to invalidate the cache after a deploy"
  value       = aws_cloudfront_distribution.frontend.id
}

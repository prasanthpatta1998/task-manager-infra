output "api_base_url" {
  description = "Base URL for the API. Configure the frontend API base URL to this value."
  value       = module.alb.api_base_url
}

output "frontend_bucket_name" {
  description = "Private S3 bucket name for the built frontend files."
  value       = module.frontend.bucket_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID for cache invalidation."
  value       = module.frontend.distribution_id
}

output "frontend_url" {
  description = "CloudFront URL for the frontend."
  value       = module.frontend.distribution_url
}

output "ecs_cluster_name" {
  value = module.ecs.cluster_name
}

output "ecs_service_name" {
  value = module.ecs.service_name
}

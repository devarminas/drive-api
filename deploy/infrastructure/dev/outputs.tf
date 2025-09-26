# VPC Outputs
output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

# RDS Outputs
output "db_endpoint" {
  value = module.rds.db_endpoint
}

output "db_port" {
  value = module.rds.db_port
}

output "rds_master_user_secret_arn" {
  value = module.rds.master_user_secret_arn
}

# ECS Outputs
output "ecs_cluster_id" {
  value = module.ecs.cluster_id
}

output "ecs_service_name" {
  value = module.ecs.service_name
}

output "load_balancer_dns_name" {
  value = module.ecs.load_balancer_dns_name
}

# S3 CloudFront Outputs
output "s3_bucket_name" {
  value = module.s3_cloudfront.bucket_name
}

output "cloudfront_domain_name" {
  value = module.s3_cloudfront.cloudfront_domain_name
}

output "sqs_queue_url" {
  value = module.s3_cloudfront.sqs_queue_url
}

output "sqs_queue_name" {
  value = module.s3_cloudfront.sqs_queue_name
}

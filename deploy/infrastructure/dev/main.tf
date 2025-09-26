terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket         = "devarminas-terraform-state"
    key            = "drive-api/dev/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "devarminas-terraform-locks"
  }
}

provider "aws" {
  region = "eu-central-1"
}

locals {
  environment = "dev"
  common_tags = {
    Environment = local.environment
    Project     = "drive-api"
    ManagedBy   = "terraform"
  }
}

# Data sources for AZs
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ecr_repository" "app" {
  name = "devarminas/drive-api"
}

# VPC Module
module "vpc" {
  source = "../modules/vpc"

  vpc_name             = "drive-api-${local.environment}"
  availability_zones   = slice(data.aws_availability_zones.available.names, 0, 2)
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
  enable_nat_gateway   = false
  tags                 = local.common_tags
}

# RDS Module
module "rds" {
  source = "../modules/rds"

  environment         = local.environment
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  db_name             = "drive"
  db_username         = "postgres"
  publicly_accessible = true
  # Allow from VPC and optionally developer's IP for direct local access
  allowed_cidr_blocks = compact(["10.0.0.0/16", var.developer_ip_cidr])
  tags                = local.common_tags
}

# S3 and CloudFront Module
module "s3_cloudfront" {
  source = "../modules/s3-cloudfront"

  environment    = local.environment
  bucket_name    = "drive-api-${local.environment}-files"
  sqs_queue_name = "drive-api-${local.environment}-upload-completed"
  tags           = local.common_tags
}

module "iam" {
  source = "../modules/iam"

  environment          = local.environment
  secrets_manager_arns = [module.rds.master_user_secret_arn]
  ssm_parameter_arns   = ["arn:aws:ssm:eu-central-1:*:parameter/drive-api/dev/*"]
  s3_bucket_arns       = [module.s3_cloudfront.bucket_arn]
  sqs_queue_arns       = [module.s3_cloudfront.sqs_queue_arn]
  ecr_repository_arns  = [data.aws_ecr_repository.app.arn]
  tags                 = local.common_tags
}

# Shared dev configuration in SSM Parameter Store
resource "aws_ssm_parameter" "dev_s3_bucket_name" {
  name  = "/drive-api/dev/S3_BUCKET_NAME"
  type  = "String"
  value = module.s3_cloudfront.bucket_name
}

resource "aws_ssm_parameter" "dev_cloudfront_domain" {
  name  = "/drive-api/dev/CLOUDFRONT_DOMAIN"
  type  = "String"
  value = module.s3_cloudfront.cloudfront_domain_name
}

resource "aws_ssm_parameter" "dev_queues_upload_completed" {
  name  = "/drive-api/dev/Queues/UploadCompleted"
  type  = "String"
  value = module.s3_cloudfront.sqs_queue_name
}

# Shared dev configuration in SSM Parameter Store
resource "aws_ssm_parameter" "dev_clerk_authority" {
  name  = "/drive-api/dev/Clerk/Authority"
  type  = "String"
  value = "https://comic-kitten-33.clerk.accounts.dev"
}

resource "aws_ssm_parameter" "dev_clerk_authorized_party" {
  name  = "/drive-api/dev/Clerk/AuthorizedParty"
  type  = "String"
  value = "http://localhost:5173"
}

resource "aws_ssm_parameter" "dev_db_secret_name" {
  name  = "/drive-api/dev/Db/SecretName"
  type  = "String"
  value = module.rds.master_user_secret_name
}

# ECS Module
module "ecs" {
  source = "../modules/ecs"

  cluster_name       = "drive-api-${local.environment}"
  service_name       = "drive-api-${local.environment}"
  container_name     = "drive-api"
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids
  image_repository   = data.aws_ecr_repository.app.repository_url
  image_tag          = var.image_tag
  container_port     = 8080
  cpu                = "256"
  memory             = "512"
  desired_count      = 1
  health_check_path  = "/healthz"
  execution_role_arn = module.iam.ecs_execution_role_arn
  task_role_arn      = module.iam.ecs_task_role_arn

  environment_variables = {
    ASPNETCORE_ENVIRONMENT = "Development"
  }

  # Cost-optimized dev: run tasks in public subnets with public IP (no NAT)
  assign_public_ip                   = true
  task_subnet_ids                    = module.vpc.public_subnet_ids
  prefer_fargate_spot                = true
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  tags = local.common_tags
}

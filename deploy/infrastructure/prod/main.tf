terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket = "devarminas-terraform-state"
    key    = "drive-api/prod/terraform.tfstate"
    region = "eu-central-1"
  }
}

provider "aws" {
  region = "eu-central-1"
}

locals {
  environment = "prod"
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
  name = "arminasdev/drive-api"
}

# VPC Module
module "vpc" {
  source = "../modules/vpc"

  availability_zones   = slice(data.aws_availability_zones.available.names, 0, 3)
  public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
  private_subnet_cidrs = ["10.1.11.0/24", "10.1.12.0/24", "10.1.13.0/24"]
  vpc_cidr             = "10.1.0.0/16"
  enable_nat_gateway   = true
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
  publicly_accessible = false
  allowed_cidr_blocks = ["10.1.0.0/16"] # VPC CIDR
  tags                = local.common_tags
}

# S3 and CloudFront Module
module "s3_cloudfront" {
  source = "../modules/s3-cloudfront"

  environment            = local.environment
  bucket_name            = "drive-api-${local.environment}-files"
  sqs_queue_name         = "drive-api-${local.environment}-upload-completed"
  cloudfront_price_class = "PriceClass_All" # Better performance for prod
  tags                   = local.common_tags
}

module "iam" {
  source = "../modules/iam"

  environment          = local.environment
  secrets_manager_arns = [module.rds.master_user_secret_arn]
  s3_bucket_arns       = [module.s3_cloudfront.bucket_arn]
  sqs_queue_arns       = [module.s3_cloudfront.sqs_queue_arn]
  tags                 = local.common_tags
}

# App Runner Module
module "apprunner" {
  source = "../modules/apprunner"

  service_name        = "drive-api-${local.environment}"
  image_repository    = data.aws_ecr_repository.app.repository_url
  image_tag           = var.image_tag
  ecr_access_role_arn = module.iam.apprunner_ecr_access_role_arn
  instance_role_arn   = module.iam.apprunner_instance_role_arn
  subnet_ids          = module.vpc.private_subnet_ids
  security_group_ids  = [module.rds.security_group_id]
  cpu                 = "1024"
  memory              = "2048"
  port                = "3000"

  environment_variables = {
    DB_SECRET_ARN     = module.rds.master_user_secret_arn
    S3_BUCKET_NAME    = module.s3_cloudfront.bucket_name
    SQS_QUEUE_URL     = module.s3_cloudfront.sqs_queue_url
    CLOUDFRONT_DOMAIN = module.s3_cloudfront.cloudfront_domain_name
    ENVIRONMENT       = local.environment
  }

  tags = local.common_tags
}

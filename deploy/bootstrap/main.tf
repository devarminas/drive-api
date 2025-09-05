terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  project             = "drive-api"
  state_bucket_name   = "devarminas-terraform-state"
  lock_table_name     = "devarminas-terraform-locks"
  ecr_repository_name = "arminasdev/drive-api"
  oidc_provider_url   = "https://token.actions.githubusercontent.com"
  github_repo_pattern = "repo:arminasdev/drive-api:*"
  common_tags = {
    Project   = local.project
    ManagedBy = "terraform"
  }
}

# S3 bucket for Terraform state
resource "aws_s3_bucket" "tf_state" {
  bucket = local.state_bucket_name
  tags   = local.common_tags
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket                  = aws_s3_bucket.tf_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB lock table
resource "aws_dynamodb_table" "tf_lock" {
  name         = local.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
  tags = local.common_tags
}

# ECR repository
resource "aws_ecr_repository" "app" {
  name = local.ecr_repository_name
  image_scanning_configuration { scan_on_push = true }
  image_tag_mutability = "MUTABLE"
  tags                 = local.common_tags
}

# GitHub OIDC Provider
resource "aws_iam_openid_connect_provider" "github" {
  url             = local.oidc_provider_url
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# IAM role for Terraform (broad infra permissions)
resource "aws_iam_role" "gha_terraform" {
  name = "drive-api-github-terraform"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn },
      Action    = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = { "token.actions.githubusercontent.com:aud" : "sts.amazonaws.com" },
        StringLike   = { "token.actions.githubusercontent.com:sub" : local.github_repo_pattern }
      }
    }]
  })
  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "gha_terraform_admin" {
  role       = aws_iam_role.gha_terraform.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AdministratorAccess"
}

# IAM role for Deploy (ECR push, ECS deploy, pass roles)
resource "aws_iam_role" "gha_deploy" {
  name = "drive-api-github-deploy"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn },
      Action    = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = { "token.actions.githubusercontent.com:aud" : "sts.amazonaws.com" },
        StringLike   = { "token.actions.githubusercontent.com:sub" : local.github_repo_pattern }
      }
    }]
  })
  tags = local.common_tags
}

resource "aws_iam_role_policy" "gha_deploy_policy" {
  name = "drive-api-github-deploy"
  role = aws_iam_role.gha_deploy.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "ecs:DescribeTaskDefinition",
          "ecs:RegisterTaskDefinition",
          "ecs:UpdateService",
          "ecs:DescribeServices",
          "ecs:DescribeClusters"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = ["iam:PassRole"],
        Resource = [
          "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/drive-api-*-ecs-execution-role",
          "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/drive-api-*-ecs-task-role"
        ]
      }
    ]
  })
}

output "state_bucket" { value = aws_s3_bucket.tf_state.bucket }
output "lock_table" { value = aws_dynamodb_table.tf_lock.name }
output "ecr_repo_url" { value = aws_ecr_repository.app.repository_url }
output "gha_terraform_role_arn" { value = aws_iam_role.gha_terraform.arn }
output "gha_deploy_role_arn" { value = aws_iam_role.gha_deploy.arn }


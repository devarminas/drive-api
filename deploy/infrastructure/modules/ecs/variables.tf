variable "cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
}

variable "service_name" {
  description = "Name of the ECS service"
  type        = string
}

variable "container_name" {
  description = "Name of the container"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for ALB"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for ECS tasks"
  type        = list(string)
}

variable "image_repository" {
  description = "ECR repository URL"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag"
  type        = string
  default     = "latest"
}

variable "container_port" {
  description = "Port exposed by the docker image to redirect traffic to"
  type        = number
  default     = 8080
}

variable "cpu" {
  description = "Number of cpu units used by the task"
  type        = string
  default     = "512"
}

variable "memory" {
  description = "Amount (in MiB) of memory used by the task"
  type        = string
  default     = "1024"
}

variable "desired_count" {
  description = "Number of instances of the task definition to place and keep running"
  type        = number
  default     = 2
}

variable "health_check_path" {
  description = "Health check path for the load balancer"
  type        = string
  default     = "/healthz"
}

variable "log_retention_in_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "environment_variables" {
  description = "Environment variables to pass to the container"
  type        = map(string)
  default     = {}
}

variable "execution_role_arn" {
  description = "ARN of the task execution role"
  type        = string
}

variable "task_role_arn" {
  description = "ARN of the task role"
  type        = string
}

variable "tags" {
  description = "A map of tags to assign to the resource"
  type        = map(string)
  default     = {}
}

variable "assign_public_ip" {
  description = "Whether to assign a public IP to ECS tasks"
  type        = bool
  default     = false
}

variable "task_subnet_ids" {
  description = "Subnets for ECS tasks (defaults to private_subnet_ids)"
  type        = list(string)
  default     = []
}

variable "prefer_fargate_spot" {
  description = "Prefer FARGATE_SPOT capacity provider for cost savings"
  type        = bool
  default     = false
}

variable "deployment_minimum_healthy_percent" {
  description = "Lower limit on the number of running tasks during a deployment"
  type        = number
  default     = 100
}

variable "deployment_maximum_percent" {
  description = "Upper limit on the number of running tasks during a deployment"
  type        = number
  default     = 200
}

variable "enable_deployment_circuit_breaker" {
  description = "Enable ECS deployment circuit breaker with rollback"
  type        = bool
  default     = true
}

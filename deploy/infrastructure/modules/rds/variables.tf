variable "vpc_id" {
  description = "ID of the VPC in which to create the DB subnet group"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the DB subnet group"
  type        = list(string)
}

variable "db_name" {
  description = "Initial database name"
  type        = string
  default     = "app_db"
}

variable "db_username" {
  description = "Master username for the database"
  type        = string
  default     = "postgres"
}

variable "publicly_accessible" {
  description = "Whether the DB instance has a public IP"
  type        = bool
  default     = false
}

variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to connect (will create ingress rules on port 5432)"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "environment" {
  description = "Environment name for resource naming"
  type        = string
}

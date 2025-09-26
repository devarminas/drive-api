output "db_endpoint" {
  description = "The connection endpoint (hostname) for the RDS instance"
  value       = aws_db_instance.this.address
}

output "db_port" {
  description = "The port on which the RDS accepts connections"
  value       = aws_db_instance.this.port
}

output "db_identifier" {
  description = "The RDS instance identifier"
  value       = aws_db_instance.this.id
}

output "security_group_id" {
  description = "Security group ID attached to the RDS instance"
  value       = aws_security_group.this.id
}

output "master_user_secret_arn" {
  description = "The ARN of the master user secret in Secrets Manager"
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}

output "master_user_secret_name" {
  description = "The name of the master user secret in Secrets Manager"
  value       = split(":", aws_db_instance.this.master_user_secret[0].secret_arn)[6]
}

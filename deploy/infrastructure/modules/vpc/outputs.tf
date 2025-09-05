output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  value = [for s in aws_subnet.public : s.id]
}

output "private_subnet_ids" {
  value = [for s in aws_subnet.private : s.id]
}

output "internet_gateway_id" {
  value = aws_internet_gateway.this.id
}

output "nat_gateway_id" {
  # When NAT Gateway is disabled, this resource has count = 0.
  # Return the first NAT Gateway ID when present; otherwise null.
  value = length(aws_nat_gateway.this) > 0 ? aws_nat_gateway.this[0].id : null
}

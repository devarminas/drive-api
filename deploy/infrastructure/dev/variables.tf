variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
} 

variable "developer_ip_cidr" {
  description = "Your public IP in CIDR format, e.g., 203.0.113.42/32, to allow direct DB access"
  type        = string
  default     = ""
}

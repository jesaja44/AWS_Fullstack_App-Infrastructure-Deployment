variable "region" {
  type        = string
  description = "AWS region for all resources (e.g., eu-central-1)"
}

variable "key_name" {
  type        = string
  description = "Name of the existing EC2 key pair"
}

variable "db_username" {
  type        = string
  description = "PostgreSQL master username"
}

variable "db_password" {
  type        = string
  description = "PostgreSQL master password"
  sensitive   = true
}

variable "db_name" {
  type        = string
  description = "Initial PostgreSQL database name"
}

variable "bucket_name" {
  type        = string
  description = "Globally-unique S3 bucket name for avatars"
}

# VPC in die deployt wird (z. B. Default-VPC)
variable "vpc_id" {
  type        = string
  description = "VPC ID to deploy into (e.g., vpc-abc123)"
}

variable "allowed_ssh_cidr" {
  type        = string
  description = "CIDR permitted to SSH into EC2 on port 22 (e.g. 1.2.3.4/32)"
}

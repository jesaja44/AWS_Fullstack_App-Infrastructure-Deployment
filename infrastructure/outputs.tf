output "ec2_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.web.public_ip
}

output "ec2_public_dns" {
  description = "Public DNS of the EC2 instance"
  value       = aws_instance.web.public_dns
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint (host)"
  value       = aws_db_instance.postgres.address
}

output "s3_bucket" {
  description = "Name of the S3 bucket for avatars"
  value       = aws_s3_bucket.avatars.bucket
}
output "alb_dns" { value = aws_lb.app.dns_name }
output "alb_tg_arn" { value = aws_lb_target_group.app_tg.arn }

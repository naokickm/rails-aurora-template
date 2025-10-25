# terraform/outputs.tf

# 最も重要な出力のみをまとめる

output "load_balancer_dns" {
  value       = aws_lb.main.dns_name
  description = "Access your Rails app at this URL (e.g., http://xxxx.ap-northeast-1.elb.amazonaws.com)"
}

output "ecr_login_command" {
  value       = "aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${aws_ecr_repository.app.repository_url}"
  description = "Command to login to ECR"
}

output "database_host" {
  value       = aws_rds_cluster.main.endpoint
  description = "Aurora MySQL cluster endpoint"
}
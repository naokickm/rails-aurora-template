variable "aws_region" {
  default = "ap-northeast-1"
}

variable "app_name" {
  default = "rails-app"
}

variable "environment" {
  default = "production"
}

variable "container_port" {
  default = 3000
}

variable "container_cpu" {
  default = 256
}

variable "container_memory" {
  default = 512
}
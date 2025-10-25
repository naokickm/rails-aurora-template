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
  description = "ECS task CPU units (256 = 0.25 vCPU, smallest option)"
  default     = 256
}

variable "container_memory" {
  description = "ECS task memory in MB (512MB, smallest option for CPU 256)"
  default     = 512
}

variable "desired_count" {
  description = "Number of ECS tasks to run (1 = cheapest, 2+ = high availability)"
  default     = 1
}

variable "rails_master_key" {
  description = "Rails master key for credentials encryption"
  type        = string
  sensitive   = true
}
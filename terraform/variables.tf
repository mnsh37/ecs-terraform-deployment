variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
}

variable "ecr_repo" {
  description = "ECR repository"
  type        = string
}


variable "rds_username" {
  description = "Username for RDS"
  type        = string
}

variable "rds_password" {
  description = "Password for RDS"
  type        = string
  sensitive   = true
}

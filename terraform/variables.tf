variable "rds_username" {
  description = "Username for RDS"
  type        = string
}

variable "rds_password" {
  description = "Password for RDS"
  type        = string
  sensitive   = true
}

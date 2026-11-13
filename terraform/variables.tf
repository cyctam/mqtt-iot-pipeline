# variables.tf
variable "your_id" {
  description = "Your unique identifier"
  type        = string
  default     = "lks02"  
}

variable "db_password" {
  description = "RDS master password"
  type        = string
  sensitive   = true
  default     = "LKSTryout2026!"
}

variable "notification_email" {
  description = "Email for SNS notifications"
  type        = string
  default     = "adityailhampratama@gmail.com"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}
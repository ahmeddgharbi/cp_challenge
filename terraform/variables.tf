variable "aws_region" {
  description = "AWS region"
  default     = "eu-central-1"
}

variable "ec2_instance_type" {
  description = "EC2 instance type"
  default     = "t2.micro"
}

variable "github_username" {
  description = "Your GitHub username"
  type        = string
}

variable "github_repo" {
  description = "Your GitHub repository name"
  type        = string
}

variable "db_instance_class" {
  description = "RDS instance class"
  default     = "db.t3.micro"
}

variable "db_username" {
  description = "Database username"
  default     = "notejamadmin"
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "db_storage" {
  description = "Allocated storage for RDS"
  default     = 20
}

variable "db_name" {
  description = "The name of the database to create"
  type        = string
}

variable "key_name" {
  description = "The name of the EC2 key pair"
  type        = string
}
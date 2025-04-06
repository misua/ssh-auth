variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "ssh_key_name" {
  description = "Name of SSH key pair to use for instances"
  type        = string
  default     = "bastion1"
}

variable "username" {
  description = "Username of the VM owner"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "purpose" {
  description = "Purpose of the VM"
  type        = string
}

variable "expiration_date" {
  description = "Date when the VM should be terminated (YYYY-MM-DD)"
  type        = string
}

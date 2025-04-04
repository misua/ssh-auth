variable "aws_region" {
  description = "AWS region to deploy resources"
  default     = "us-east-1"
}

variable "environment_name" {
  description = "Name of the environment"
  default     = "prod"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "vault_instance_type" {
  description = "Instance type for Vault server"
  default     = "t2.micro"
}

variable "jumpbox_instance_type" {
  description = "Instance type for jumpbox instances"
  default     = "t2.micro"
}

variable "ssh_key_name" {
  description = "Name of SSH key pair to use for instances"
}

variable "environments" {
  description = "List of environments to deploy jumpboxes for"
  type        = list(string)
  default     = ["dev", "staging", "prod"]
}

variable "name" {
  description = "Name prefix for Vault resources"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC to deploy Vault into"
  type        = string
}

variable "subnet_ids" {
  description = "IDs of subnets to deploy Vault into"
  type        = list(string)
}

variable "instance_type" {
  description = "EC2 instance type for Vault server"
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "Name of SSH key pair to use for Vault server"
  type        = string
}

variable "environments" {
  description = "List of environments to configure access roles for"
  type        = list(string)
  default     = ["dev", "staging", "prod"]
}

variable "logging_server_ip" {
  description = "IP address of the Loki logging server"
  type        = string
}

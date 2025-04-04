variable "name" {
  description = "Name prefix for jumpbox resources"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC to deploy jumpboxes into"
  type        = string
}

variable "subnet_ids" {
  description = "IDs of subnets to deploy jumpboxes into"
  type        = list(string)
}

variable "instance_type" {
  description = "EC2 instance type for jumpbox instances"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Name of SSH key pair to use for jumpbox instances"
  type        = string
}

variable "vault_ip" {
  description = "IP address of the Vault server"
  type        = string
}

variable "vault_ca_pub_key" {
  description = "SSH CA public key from Vault"
  type        = string
}

variable "environments" {
  description = "List of environments to deploy jumpboxes for"
  type        = list(string)
  default     = ["dev", "staging", "prod"]
}

variable "logging_server_ip" {
  description = "IP address of the Loki logging server"
  type        = string
}

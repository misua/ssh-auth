variable "environment" {
  description = "Environment name (e.g., prod, dev, staging)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the logging infrastructure will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs where the logging infrastructure will be deployed"
  type        = list(string)
}

variable "key_name" {
  description = "SSH key name to use for the logging instance"
  type        = string
}

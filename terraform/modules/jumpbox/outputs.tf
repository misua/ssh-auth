output "public_ips" {
  description = "Public IP addresses of the jumpbox instances"
  value       = aws_instance.jumpbox[*].public_ip
}

output "instance_ids" {
  description = "Instance IDs of the jumpbox instances"
  value       = aws_instance.jumpbox[*].id
}

output "environment_mapping" {
  description = "Mapping of environments to jumpbox public IPs"
  value = {
    for i, env in var.environments : env => aws_instance.jumpbox[i].public_ip
  }
}

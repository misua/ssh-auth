output "logging_private_ip" {
  description = "Private IP address of the logging server"
  value       = module.logging.private_ip
}

output "logging_public_ip" {
  description = "Public IP address of the logging server"
  value       = module.logging.public_ip
}

output "vault_private_ip" {
  description = "Private IP address of the Vault server"
  value       = module.vault.private_ip
}

output "vault_public_ip" {
  description = "Public IP address of the Vault server (if assigned)"
  value       = module.vault.public_ip
}

output "jumpbox_public_ips" {
  description = "Public IP addresses of the jumpbox instances"
  value       = module.jumpbox.public_ips
}

output "jumpbox_environment_mapping" {
  description = "Mapping of environments to jumpbox public IPs"
  value       = module.jumpbox.environment_mapping
}

output "ssh_ca_public_key" {
  description = "SSH CA public key from Vault"
  value       = module.vault.ssh_ca_public_key
}

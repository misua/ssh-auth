output "private_ip" {
  description = "Private IP address of the Vault server"
  value       = aws_instance.vault.private_ip
}

output "public_ip" {
  description = "Public IP address of the Vault server (if assigned)"
  value       = aws_instance.vault.public_ip
}

output "ssh_ca_public_key" {
  description = "SSH CA public key from Vault"
  value       = local.ssh_ca_public_key
}

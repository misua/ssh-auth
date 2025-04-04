output "private_ip" {
  description = "Private IP address of the logging server"
  value       = aws_instance.logging.private_ip
}

output "public_ip" {
  description = "Public IP address of the logging server"
  value       = aws_instance.logging.public_ip
}

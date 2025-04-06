provider "aws" {
  region = var.aws_region
}

# Reference existing VPC and subnets
data "terraform_remote_state" "infrastructure" {
  backend = "local"
  config = {
    path = "../terraform.tfstate"
  }
}

# Create on-demand VM
resource "aws_instance" "on_demand" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  subnet_id     = data.terraform_remote_state.infrastructure.outputs.private_subnet_ids[0]
  key_name      = var.ssh_key_name
  
  vpc_security_group_ids = [aws_security_group.on_demand.id]
  
  user_data = templatefile("${path.module}/templates/vm_setup.sh.tpl", {
    vault_ca_pub_key = data.terraform_remote_state.infrastructure.outputs.ssh_ca_public_key
    environment = var.environment
    username = var.username
  })
  
  tags = {
    Name = "on-demand-${var.username}-${formatdate("YYYYMMDD-hhmmss", timestamp())}"
    Owner = var.username
    Purpose = var.purpose
    ExpirationDate = var.expiration_date
  }
}

# Security group for on-demand VM
resource "aws_security_group" "on_demand" {
  name        = "on-demand-${var.username}-${formatdate("YYYYMMDD-hhmmss", timestamp())}"
  description = "Security group for on-demand VM"
  vpc_id      = data.terraform_remote_state.infrastructure.outputs.vpc_id
  
  # Allow SSH from jumpbox security group
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # VPC CIDR
  }
  
  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# AMI lookup
data "aws_ami" "ubuntu" {
  most_recent = true
  
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  
  owners = ["099720109477"] # Canonical
}

# Output the VM details
output "instance_id" {
  value = aws_instance.on_demand.id
}

output "private_ip" {
  value = aws_instance.on_demand.private_ip
}

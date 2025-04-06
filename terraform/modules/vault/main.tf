# Security group for Vault server
resource "aws_security_group" "vault" {
  name        = "${var.name}-sg"
  description = "Security group for Vault server"
  vpc_id      = var.vpc_id

  # Allow inbound SSH from jumpboxes
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
    description = "SSH access from internal network"
  }

  # Allow inbound Vault API traffic
  ingress {
    from_port   = 8200
    to_port     = 8200
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
    description = "Vault API access from internal network"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name}-sg"
  }
}

# IAM role for Vault server
resource "aws_iam_role" "vault" {
  count = var.create_iam_resources ? 1 : 0
  name = "${var.name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
  
  # Using lifecycle meta-argument for easier deletion
  lifecycle {
    create_before_destroy = true
  }
}

# IAM policy for CloudWatch logging
resource "aws_iam_role_policy" "vault_cloudwatch" {
  count  = var.create_iam_resources ? 1 : 0
  name   = "${var.name}-cloudwatch-policy"
  role   = var.create_iam_resources ? aws_iam_role.vault[0].id : "${var.name}-role"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ],
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# IAM instance profile for Vault server
resource "aws_iam_instance_profile" "vault" {
  name = "${var.name}-instance-profile"
  role = var.create_iam_resources ? aws_iam_role.vault[0].name : "${var.name}-role"
}

# Create Vault server
resource "aws_instance" "vault" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = var.subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.vault.id]
  iam_instance_profile   = aws_iam_instance_profile.vault.name

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
  }

  user_data = join("\n", [
    templatefile("${path.module}/templates/vault_setup.sh.tpl", {
      environments = var.environments
    }),
    templatefile("${path.module}/templates/promtail_setup.sh.tpl", {
      logging_server_ip = var.logging_server_ip,
      PROMTAIL_VERSION = "2.8.0"
    })
  ])

  tags = {
    Name = var.name
  }
}

# Get latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Terraform local values
locals {
  # This would normally be retrieved from Vault after initialization
  # For demo purposes, we're using a placeholder that the user_data script will replace
  ssh_ca_public_key = "ssh-ca-public-key-placeholder"
}

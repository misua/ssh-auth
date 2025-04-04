# Security group for jumpbox instances
resource "aws_security_group" "jumpbox" {
  name        = "${var.name}-sg"
  description = "Security group for jumpbox instances"
  vpc_id      = var.vpc_id

  # Allow inbound SSH from anywhere (for demo purposes)
  # In production, restrict this to your corporate IP ranges
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
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

# IAM role for jumpbox instances
resource "aws_iam_role" "jumpbox" {
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
}

# IAM instance profile for jumpbox instances
resource "aws_iam_instance_profile" "jumpbox" {
  name = "${var.name}-instance-profile"
  role = aws_iam_role.jumpbox.name
}

# IAM policy for accessing SSM
resource "aws_iam_policy" "ssm_access" {
  name        = "${var.name}-ssm-access"
  description = "Allow instances to access SSM"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "ssm:UpdateInstanceInformation",
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

# Attach SSM policy to role
resource "aws_iam_role_policy_attachment" "ssm_policy_attach" {
  role       = aws_iam_role.jumpbox.name
  policy_arn = aws_iam_policy.ssm_access.arn
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

# Create jumpbox instances for each environment
resource "aws_instance" "jumpbox" {
  count                  = length(var.environments)
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = element(var.subnet_ids, count.index % length(var.subnet_ids))
  vpc_security_group_ids = [aws_security_group.jumpbox.id]
  iam_instance_profile   = aws_iam_instance_profile.jumpbox.name

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
  }

  user_data = templatefile("${path.module}/templates/jumpbox_setup.sh.tpl", {
    vault_ip         = var.vault_ip
    vault_ca_pub_key = var.vault_ca_pub_key
    environment      = var.environments[count.index]
  })

  tags = {
    Name        = "${var.name}-${var.environments[count.index]}"
    Environment = var.environments[count.index]
  }
}

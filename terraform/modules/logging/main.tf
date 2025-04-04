resource "aws_instance" "logging" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  key_name               = var.key_name
  subnet_id              = var.subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.logging.id]
  iam_instance_profile   = aws_iam_instance_profile.logging.name

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
  }

  # User data script to set up Loki and Grafana
  user_data = templatefile("${path.module}/templates/logging_setup.sh.tpl", {
    COMPOSE_VERSION = "1.29.2"
  })

  tags = {
    Name = "${var.environment}-logging"
  }
}

resource "aws_security_group" "logging" {
  name        = "${var.environment}-logging-sg"
  description = "Security group for Loki and Grafana"
  vpc_id      = var.vpc_id

  # Allow Grafana web access
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
    description = "Grafana web interface"
  }

  # Allow Loki access
  ingress {
    from_port   = 3100
    to_port     = 3100
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
    description = "Loki API"
  }

  # Allow SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
    description = "SSH access"
  }

  # Allow Promtail access
  ingress {
    from_port   = 9080
    to_port     = 9080
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
    description = "Promtail access"
  }

  # Allow all internal VPC traffic (for agents to communicate)
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/8"]
    description = "Internal VPC traffic"
  }

  # Allow all outgoing traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.environment}-logging-sg"
  }
}

# IAM role for logging instance
resource "aws_iam_role" "logging" {
  name = "${var.environment}-logging-role"

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

resource "aws_iam_instance_profile" "logging" {
  name = "${var.environment}-logging-instance-profile"
  role = aws_iam_role.logging.name
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

# Output definitions moved to outputs.tf

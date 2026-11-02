terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

variable "region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "public_key_path" {
  description = "Path to your SSH public key"
  default     = "~/.ssh/devops-proj-key.pub"
}

# ---------- ECR (stores the Docker image) ----------
resource "aws_ecr_repository" "app" {
  name         = "devops-proj-app"
  force_delete = true
}

# ---------- SSH key pair ----------
resource "aws_key_pair" "key" {
  key_name   = "devops-proj-key"
  public_key = file(var.public_key_path)
}

# ---------- Security group (firewall) ----------
resource "aws_security_group" "web" {
  name        = "devops-proj-web-sg"
  description = "Allow SSH, HTTP, HTTPS"

  ingress {
    description = "SSH (restrict to your IP in real setups)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------- IAM role so EC2 can pull from ECR ----------
resource "aws_iam_role" "ec2" {
  name = "devops-proj-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_read" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "devops-proj-ec2-profile"
  role = aws_iam_role.ec2.name
}

# ---------- EC2 server ----------
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.key.key_name
  vpc_security_group_ids = [aws_security_group.web.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  root_block_device {
    volume_size = 20
  }

  tags = {
    Name = "devops-proj-server"
  }
}

# Fixed IP so the address survives restarts
resource "aws_eip" "app" {
  instance = aws_instance.app.id
}

output "public_ip" {
  value = aws_eip.app.public_ip
}

output "ecr_repo_url" {
  value = aws_ecr_repository.app.repository_url
}

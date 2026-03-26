terraform {
  # The S3 backend for storing the state file safely across Jenkins builds
  backend "s3" {
    bucket = "denis-s3-bucket-for-devops-course"
    key    = "production/terraform.tfstate"
    region = "eu-central-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = { 
      source  = "hashicorp/tls" 
      version = "~> 4.0" 
    }
    local = { 
      source  = "hashicorp/local" 
      version = "~> 2.0" 
    }
  }
}

variable "aws_region" {
  default = "eu-central-1" # Frankfurt
}

provider "aws" {
  region = var.aws_region
}

# --- SSH Key Generation ---
resource "tls_private_key" "k8s_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = "seyoawe-k8s-key"
  public_key = tls_private_key.k8s_key.public_key_openssh
}

resource "local_file" "private_key" {
  content         = tls_private_key.k8s_key.private_key_pem
  filename        = "${path.module}/k8s-key.pem"
  file_permission = "0400"
}

# --- Network Resources ---
resource "aws_default_vpc" "default" {}

resource "aws_security_group" "seyoawe_sg" {
  name        = "seyoawe_security_group"
  description = "Allow SSH, HTTP, and K8s API"
  vpc_id      = aws_default_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 30000
    to_port     = 30000
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

# --- Compute Resources ---
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical owner ID

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

resource "aws_instance" "instance" {
  ami             = data.aws_ami.ubuntu.id
  instance_type   = "t3.medium"
  key_name        = aws_key_pair.generated_key.key_name
  security_groups = [aws_security_group.seyoawe_sg.name]

  # ADD THIS BLOCK to fix DiskPressure:
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name = "seyoawe-tier"
  }
}

# --- Outputs ---
output "public_ip" {
  value = aws_instance.instance.public_ip
}
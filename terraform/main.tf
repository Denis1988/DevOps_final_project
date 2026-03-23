terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
    tls = { source = "hashicorp/tls", version = "~> 4.0" }
    local = { source = "hashicorp/local", version = "~> 2.0" }
  }
}

provider "aws" { region = "us-east-1" }

# Generate an SSH Key Pair dynamically
resource "tls_private_key" "k8s_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = "seyoawe-k8s-key"
  public_key = tls_private_key.k8s_key.public_key_openssh
}

# Save the private key locally for Jenkins/Ansible to use [cite:93]
resource "local_file" "private_key" {
  content         = tls_private_key.k8s_key.private_key_pem
  filename        = "${path.module}/k8s-key.pem"
  file_permission = "0400"
}

# Find the latest Ubuntu 22.04 AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# Allow SSH (22), HTTP (80) and K8s API (6443)
resource "aws_security_group" "k8s_sg" {
  name        = "k8s_free_tier_sg"
  description = "Allow inbound traffic"
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
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create the Free Tier EC2 Node
resource "aws_instance" "k8s_node" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro" # Free Tier Eligible
  key_name               = aws_key_pair.generated_key.key_name
  vpc_security_group_ids = [aws_security_group.k8s_sg.id]

  tags = { Name = "seyoawe-free-tier-k3s" }
}

# Output the IP so Jenkins can pass it to Ansible
output "public_ip" {
  value = aws_instance.k8s_node.public_ip
}
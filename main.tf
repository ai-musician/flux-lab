# Ephemeral test environment on AWS EC2
# Creates: security group + Ubuntu VM with nginx installed
# Run:     terraform init
#          terraform apply
# Cleanup: terraform destroy
# No SSH: the CI test only uses HTTP (port 80), so no key pair or IP is needed.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# ---------- Inputs ----------
variable "region" {
  type    = string
  default = "us-west-2"
}

# ---------- Image (AMI): latest Ubuntu 22.04 from Canonical ----------
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# ---------- Network: security group (firewall) ----------
resource "aws_security_group" "test_sg" {
  name_prefix = "test-env-"
  description = "HTTP for tests"

  ingress {
    description = "HTTP so the CI runner can test the app"
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

# ---------- The VM: Type, Storage, Launch ----------
resource "aws_instance" "test_vm" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.test_sg.id]

  root_block_device {
    volume_size = 20 # GB (EBS disk)
  }

  # "Deploy the product": startup script runs on first boot
  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y nginx
    systemctl enable --now nginx
  EOF

  tags = {
    Name = "ephemeral-test-env"
  }
}

# ---------- Output: used by the test step ----------
output "public_ip" {
  value = aws_instance.test_vm.public_ip
}

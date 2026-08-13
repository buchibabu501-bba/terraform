terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance size"
  type        = string
  default     = "t2.micro"
}

variable "ami_name_filter" {
  description = "Name filter for the Amazon Linux 2023 AMI"
  type        = string
  default     = "al2023-ami-2023.*-x86_64"
}

variable "key_name" {
  description = "Optional EC2 key pair name"
  type        = string
  default     = null
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed to reach SSH"
  type        = string
  default     = "0.0.0.0/0"
}

variable "cluster" {
  description = "Cluster/environment name"
  type        = string
  default     = "dev"
}

variable "instance_names" {
  description = "List of EC2 instance names to create"
  type        = list(string)
  default     = []
}

variable "instances" {
  description = "List of instance objects. Each object: { name = string, state = string }. If empty, `instance_names` is used with default state 'active'."
  type = list(object({ name = string, state = string }))
  default = []
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = [var.ami_name_filter]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  instances_list = length(var.instances) > 0 ? var.instances : [for n in var.instance_names : { name = n, state = "active" }]
  active_instances = { for inst in local.instances_list : inst.name => inst if inst.state != "shutdown" }
}

resource "aws_security_group" "web_sg" {
  name_prefix = "terraform-ec2-sg-"
  description = "Allow SSH access to EC2 instances"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "web" {
  for_each = local.active_instances

  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.web_sg.id]

  tags = {
    Name    = each.key
    Cluster = var.cluster
  }
}

output "instance_ids" {
  value = [for i in aws_instance.web : i.id]
}

output "public_ips" {
  value = [for i in aws_instance.web : i.public_ip]
}

output "instance_public_dns" {
  value = [for i in aws_instance.web : i.public_dns]
}

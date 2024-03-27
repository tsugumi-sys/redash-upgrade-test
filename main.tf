locals {
  # Redash recommend AMI for us-west-2
  # https://redash.io/help/open-source/setup#aws
  ami           = "ami-060741a96307668be"
  instance_type = "t2.small"
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "ap-northeast-1"

  default_tags {
    tags = {
      Name = "Redash-Upgade-Test"
    }
  }
}

resource "aws_vpc" "redash_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_subnet" "redash_subnet" {
  vpc_id                  = aws_vpc.redash_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "redash_igw" {
  vpc_id = aws_vpc.redash_vpc.id
}

resource "aws_route_table" "redash_route_table" {
  vpc_id = aws_vpc.redash_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.redash_igw.id
  }
}

resource "aws_route_table_association" "redash_route_association" {
  subnet_id      = aws_subnet.redash_subnet.id
  route_table_id = aws_route_table.redash_route_table.id
}

resource "aws_security_group" "redash" {
  name        = "redash_sg"
  description = "Allow ssh and http"
  vpc_id      = aws_vpc.redash_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

resource "aws_ebs_volume" "redash_ebs" {
  availability_zone = aws_instance.redash_instance.availability_zone
  size              = 10 # GB
}

resource "aws_volume_attachment" "redash_ebs_attach" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.redash_ebs.id
  instance_id = aws_instance.redash_instance.id
}

resource "aws_instance" "redash_instance" {
  ami                         = local.ami
  instance_type               = local.instance_type
  subnet_id                   = aws_subnet.redash_subnet.id
  vpc_security_group_ids      = [aws_security_group.redash.id]
  associate_public_ip_address = true
  root_block_device {
    volume_size = 8 # GB
  }
}

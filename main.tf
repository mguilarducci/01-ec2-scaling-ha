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
  region = "us-east-1"
}

data "aws_vpc" "default" {
  default = true
}

resource "aws_s3_bucket" "bucket" {
  bucket = "01-ec2-scaling-ha"

  tags = {
    Name          = "01-ec2-scaling-ha",
    Environment   = "Dev",
    CreationDate  = "2022-09-27",
    MyDescription = "Exploring terraform"
  }
}


resource "aws_efs_file_system" "ec2_scaling_ha" {
  creation_token = "01-ec2-scaling-ha"
  encrypted      = true

  tags = {
    Name          = "01-ec2-scaling-ha",
    Environment   = "Dev",
    CreationDate  = "2022-09-27",
    MyDescription = "Exploring terraform"
  }
}

# iam role para s3

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description      = "SSH from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name          = "allow_ssh",
    Environment   = "Dev",
    CreationDate  = "2022-09-27",
    MyDescription = "Exploring terraform"
  }
}

resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "Allow HTTP inbound traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description      = "HTTP from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name          = "allow_http",
    Environment   = "Dev",
    CreationDate  = "2022-09-27",
    MyDescription = "Exploring terraform"
  }
}



# # subnet-04ae54f04c378b7dd

# resource "aws_instance" "instance-1" {
#   ami           = "ami-026b57f3c383c2eec"
#   instance_type = "t2.micro"

#   security_groups = [
#     aws_security_group.allow_ssh.id,
#     aws_security_group.allow_http.id,
#   ]

#   subnet_id = "subnet-093ee3482d1898987"

#   tags = {
#     Name          = "01-ec2-scaling-ha-instance-1",
#     Environment   = "Dev",
#     CreationDate  = "2022-09-27",
#     MyDescription = "Exploring terraform"
#   }
# }

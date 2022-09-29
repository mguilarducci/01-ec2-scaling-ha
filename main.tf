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

locals {
  subnets     = ["subnet-093ee3482d1898987", "subnet-04ae54f04c378b7dd"]
  today       = "2022-09-29"
  name = "01-ec2-scaling-ha"
  bucket_name = local.name
}

resource "aws_s3_bucket" "bucket" {
  bucket        = local.bucket_name
  force_destroy = true

  tags = {
    Name          = local.name,
    Environment   = "Dev",
    CreationDate  = local.today
    MyDescription = "Exploring terraform"
  }
}

resource "aws_s3_bucket_public_access_block" "bucket_access" {
  bucket = aws_s3_bucket.bucket.id

  block_public_acls   = true
  block_public_policy = true
  ignore_public_acls  = true
}

resource "aws_iam_role" "s3_full_access" {
  name = "${local.name}-MyAmazonS3FullAccess"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Name          = "${local.name}-MyAmazonS3FullAccess",
    Environment   = "Dev",
    CreationDate  = local.today
    MyDescription = "Exploring terraform"
  }
}

resource "aws_iam_policy" "bucket_policy" {
  name        = "${local.name}-bucket-policy"
  path        = "/"
  description = "Allow "

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "VisualEditor0",
        "Effect" : "Allow",
        "Action" : [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ],
        "Resource" : [
          "arn:aws:s3:::*/*",
          "arn:aws:s3:::my-bucket-name"
        ]
      }
    ]
  })

  tags = {
    Name          = "${local.name}-bucket-policy",
    Environment   = "Dev",
    CreationDate  = local.today
    MyDescription = "Exploring terraform"
  }
}

resource "aws_iam_role_policy_attachment" "bucket_policy_attachment" {
  role       = aws_iam_role.s3_full_access.name
  policy_arn = aws_iam_policy.bucket_policy.arn
}

resource "aws_iam_instance_profile" "instance_profile" {
  name = "${local.name}-instance-profile"
  role = aws_iam_role.s3_full_access.name

  tags = {
    Name          = "${local.name}-instance-profile",
    Environment   = "Dev",
    CreationDate  = local.today
    MyDescription = "Exploring terraform"
  }
}


resource "aws_efs_file_system" "ec2_scaling_ha" {
  creation_token = local.name
  encrypted      = true

  tags = {
    Name          = local.name,
    Environment   = "Dev",
    CreationDate  = local.today
    MyDescription = "Exploring terraform"
  }
}

resource "aws_efs_mount_target" "efs_mt" {
  depends_on      = [aws_security_group.allow_efs]
  count           = length(local.subnets)
  file_system_id  = aws_efs_file_system.ec2_scaling_ha.id
  subnet_id       = local.subnets[count.index]
  security_groups = [aws_security_group.allow_efs.id]
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow-ssh"
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
    Name          = "allow-ssh",
    Environment   = "Dev",
    CreationDate  = local.today
    MyDescription = "Exploring terraform"
  }
}

resource "aws_security_group" "allow_http" {
  name        = "allow-http"
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
    Name          = "allow-http",
    Environment   = "Dev",
    CreationDate  = local.today
    MyDescription = "Exploring terraform"
  }
}


resource "aws_security_group" "allow_efs" {
  name        = "allow-efs"
  description = "Allow inbound efs traffic from ec2"
  vpc_id      = data.aws_vpc.default.id


  ingress {
    description = "EFS to EC2"

    security_groups = [aws_security_group.allow_ssh.id]
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
  }

  egress {
    security_groups = [aws_security_group.allow_ssh.id]
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
  }

  tags = {
    Name          = "allow-efs",
    Environment   = "Dev",
    CreationDate  = local.today
    MyDescription = "Exploring terraform"
  }
}

resource "aws_instance" "instances" {
  depends_on = [aws_efs_file_system.ec2_scaling_ha, aws_efs_mount_target.efs_mt]

  count = length(local.subnets)

  ami           = "ami-026b57f3c383c2eec"
  instance_type = "t2.micro"

  security_groups = [
    aws_security_group.allow_ssh.id,
    aws_security_group.allow_http.id,
  ]

  subnet_id = local.subnets[count.index]

  user_data = templatefile("user_data.tftpl", {
    efs_id      = aws_efs_file_system.ec2_scaling_ha.id,
    bucket_name = local.bucket_name
  })

  iam_instance_profile = aws_iam_instance_profile.instance_profile.id

  tags = {
    Name          = "${local.name}-instance-${count.index}",
    Environment   = "Dev",
    CreationDate  = local.today
    MyDescription = "Exploring terraform"
  }
}

provider "aws" {
  region = var.region
}

resource "random_id" "suffix" {
  byte_length = 4
}

data "aws_vpc" "selected" {
  id = var.vpc_id
}

data "aws_subnets" "selected" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
}

resource "aws_security_group" "ec2_sg" {
  name_prefix = "ec2-sg-"
  vpc_id      = data.aws_vpc.selected.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["2.213.63.38/32"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "grocery-ec2-sg"
  }
}

resource "aws_security_group" "rds_sg" {
  name_prefix = "rds-sg-"
  vpc_id      = data.aws_vpc.selected.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "grocery-rds-sg"
  }
}

resource "aws_instance" "web" {
  ami                    = "ami-0394cacf99ecccb4d" # Amazon Linux 2
  instance_type          = "t2.micro"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  subnet_id              = data.aws_subnets.selected.ids[0]

  # IAM Role anhängen (hier ggf. anpassen)
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name

  tags = {
    Name = "grocery-ec2"
  }
}

resource "aws_db_subnet_group" "default" {
  name       = "grocery-db-subnet-group"
  subnet_ids = data.aws_subnets.selected.ids

  tags = {
    Name = "Grocery DB Subnet Group"
  }
}

resource "aws_db_instance" "postgres" {
  identifier             = "mario-rose-db"
  allocated_storage      = 20
  engine                 = "postgres"
  engine_version         = "15.12"
  instance_class         = "db.t3.micro"
  username               = var.db_username
  password               = var.db_password
  db_name                = var.db_name
  skip_final_snapshot    = true
  publicly_accessible    = false
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.default.name

  tags = {
    Name = "grocery-rds"
  }
}
#test
resource "aws_s3_bucket" "avatars" {
  bucket = var.bucket_name

  tags = {
    Name = var.bucket_name
  }
}

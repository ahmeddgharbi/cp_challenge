provider "aws" {
  region = var.aws_region
}

# ---------------------
# Fetch Latest Amazon Linux 2 AMI
# ---------------------
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# ---------------------
# VPC
# ---------------------
resource "aws_vpc" "main" {
  cidr_block = "10.1.0.0/16"
  tags = {
    Name = "notejam-vpc"
  }
}

# ---------------------
# Subnets (Different AZs, New CIDRs)
# ---------------------
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.1.11.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.1.12.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-b"
  }
}

# ---------------------
# Internet Gateway & Routing
# ---------------------
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

resource "aws_route_table_association" "public_assoc_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_assoc_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# ---------------------
# Security Groups
# ---------------------
resource "aws_security_group" "ec2_sg" {
  name        = "ec2-sg"
  description = "Allow HTTP traffic"
  vpc_id      = aws_vpc.main.id

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

resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  description = "Allow EC2 access to RDS"
  vpc_id      = aws_vpc.main.id

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
}

# ---------------------
# EC2 Instance with User Data
# ---------------------
resource "aws_instance" "app" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = var.ec2_instance_type
  subnet_id     = aws_subnet.public_a.id
  security_groups = [aws_security_group.ec2_sg.id]

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    amazon-linux-extras enable python3.8
    yum install -y python3.8 git

    # Install pip and virtualenv
    python3.8 -m ensurepip
    python3.8 -m pip install --upgrade pip
    pip3 install virtualenv gunicorn

    # Clone your repo
    cd /home/ec2-user
    git clone https://github.com/${var.github_username}/${var.github_repo}.git
    cd ${var.github_repo}

    # Set up virtual environment
    python3.8 -m venv venv
    source venv/bin/activate
    pip install -r requirements.txt

    # Set environment variables
    export DATABASE_URL=postgresql://${var.db_username}:${var.db_password}@${aws_db_instance.db.endpoint}:5432/postgres

    # Run app with Gunicorn
    nohup gunicorn -w 3 -b 0.0.0.0:80 runserver:app &
  EOF

  tags = {
    Name = "notejam-app"
  }
}

# ---------------------
# RDS Subnet Group
# ---------------------
resource "aws_db_subnet_group" "db_subnets" {
  name       = "db-subnet-group"
  subnet_ids = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

# ---------------------
# RDS PostgreSQL
# ---------------------
resource "aws_db_instance" "db" {
  allocated_storage      = var.db_storage
  engine                 = "postgres"
  engine_version         = "14"
  instance_class         = var.db_instance_class
  username               = var.db_username
  password               = var.db_password
  parameter_group_name   = "default.postgres14"
  skip_final_snapshot    = true
  publicly_accessible    = false
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.db_subnets.name
}

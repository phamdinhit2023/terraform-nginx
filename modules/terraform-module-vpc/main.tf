locals {
  base_name = "${var.prefix}${var.separator}${var.name}"
}

## Declare AZ in this region ##
data "aws_availability_zones" "available" {}
## Create VPC ##
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  tags = {
    Name = local.base_name
  }
}

## Create Internet Gateway ##
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "${local.base_name} Internet Gateway"

  }
}

## Create Routing table for the public subnets ##
resource "aws_route_table" "public-route-to-igw" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "${local.base_name} Public Routing Table"

  }
}
resource "aws_route" "public_subnet_internet_gateway_ipv4" {
  route_table_id         = aws_route_table.public-route-to-igw.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# resource "aws_route" "public_subnet_internet_gateway_ipv6" {
#   route_table_id              = aws_route_table.public-route-to-igw.id
#   destination_ipv6_cidr_block = "::/0"
#   gateway_id                  = aws_internet_gateway.igw.id
# }

## Create Public Subnets ##
resource "aws_subnet" "first_public_az" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.first_public_subnet_cidr
  availability_zone = data.aws_availability_zones.available.names[0]
  tags = { Name = "${local.base_name} Public Network First AZ"
  }
}

## Associate Routing table to the public subnets ##
resource "aws_route_table_association" "public_AZ1" {
  subnet_id      = aws_subnet.first_public_az.id
  route_table_id = aws_route_table.public-route-to-igw.id
}

## Create Sercurity group ##
resource "aws_security_group" "instance" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "allow_tls"
  }
   ingress {
    from_port   = var.https_port
    to_port     = var.https_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = var.http_port
    to_port     = var.http_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = var.ssh_port
    to_port     = var.ssh_port
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

resource "aws_instance" "example" {
  ami           = "ami-0672fd5b9210aa093"
  instance_type = "t2.micro"
  # security_groups = [aws_security_group.instance.id]

  vpc_security_group_ids = [aws_security_group.instance.id]
  subnet_id              = aws_subnet.first_public_az.id 
  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install nginx -y
              sudo systemctl start nginx
              sudo systemctl enable nginx

              # Cấu hình Nginx để lắng nghe HTTP và HTTPS
              sudo bash -c 'cat > /etc/nginx/sites-available/default' << EOL
              server {
                listen ${var.http_port};
                root /var/www/html;
                index index.html;
                location / {
                  try_files $uri $uri/ =404;
                }
              }

              server {
                listen ${var.https_port} ssl;
                root /var/www/html;
                index index.html;
                location / {
                  try_files $uri $uri/ =404;
                }
              }
              EOL

              sudo systemctl restart nginx

              echo "Hello, HTTPS World" > /var/www/html/index.html
              EOF
  user_data_replace_on_change = true
  associate_public_ip_address = true
  tags = {
    Name = "my-ubuntu"
  }
}

# resource "aws_launch_template" "example" {
#   name          = "${local.base_name}-launch-template"
#   image_id      = "ami-0672fd5b9210aa093"
#   instance_type = "t2.micro"

#   network_interfaces {
#     associate_public_ip_address = true
#     security_groups             = [aws_security_group.instance.name]
#     subnet_id                   = aws_subnet.first_public_az.id
#   }

#   user_data = base64encode(<<-EOF
#               #!/bin/bash
#               sudo apt update -y
#               sudo apt install nginx -y
#               sudo systemctl start nginx
#               sudo systemctl enable nginx

#               # Cấu hình Nginx để lắng nghe HTTP và HTTPS
#               sudo bash -c 'cat > /etc/nginx/sites-available/default' << EOL
#               server {
#                 listen ${var.http_port};
#                 root /var/www/html;
#                 index index.html;
#                 location / {
#                   try_files $uri $uri/ =404;
#                 }
#               }

#               server {
#                 listen ${var.https_port} ssl;
#                 root /var/www/html;
#                 index index.html;
#                 location / {
#                   try_files $uri $uri/ =404;
#                 }
#               }
#               EOL

#               sudo systemctl restart nginx

#               echo "Hello, HTTPS World" > /var/www/html/index.html
#               EOF
#   )

#   tag_specifications {
#     resource_type = "instance"
#     tags = {
#       Name = "my-ubuntu"
#     }
#   }
# }

## Create EIPs ##
resource "aws_eip" "example" {
  instance = aws_instance.example.id
  tags = {
    Name = "example-eip"
  }
}

terraform {
    backend "s3" {
        bucket = "codepipeline-tfstate-backend-01"
        key = "global/codepipeline/terraform.tfstate"
        region = "eu-west-2"
        dynamodb_table = "tfstate-locking-DB"
        encrypt = true
    }
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 4.0"
        }
    }
}
provider "aws" {
    region = "eu-west-2"
}
# create codepipeline VPC
resource "aws_vpc" "codepipeline-VPC" {
    cidr_block = "10.10.0.0/16"
    tags = {
      Name = "codepipeline-VPC"
    }
}
# create internet gateway and 
# custome route table
resource "aws_internet_gateway" "codepipeline-IGW" {
    vpc_id = aws_vpc.codepipeline-VPC.id
    tags = {
      Name = "codepipeline-IGW"
    }
}
resource "aws_route_table" "IGW-route" {
    vpc_id = aws_vpc.codepipeline-VPC.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.codepipeline-IGW.id
    }
    tags = {
      Name = "codepipeline-IGW-route"
    }
}
# create public subnet and 
# associate it with cutom IGW route table
resource "aws_subnet" "codepipeline-PUB" {
    vpc_id = aws_vpc.codepipeline-VPC.id
    cidr_block = "10.10.0.0/17"
    availability_zone = "eu-west-2a"
    tags = {
      Name = "codepipeline-PUB"
    }
}
resource "aws_route_table_association" "PUB-IGW" {
    subnet_id = aws_subnet.codepipeline-PUB.id
    route_table_id = aws_route_table.IGW-route.id
}
# create security group
resource "aws_security_group" "codepipeline-SG" {
    name = "allow web traffic"
    description = "allow web traffic for HTTP:80, HTTPS:344, and openSSH:22"
    vpc_id = aws_vpc.codepipeline-VPC.id

    ingress {
        description = "allow HTTP"
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]     
    }
    ingress {
        description = "allow HTTPS"
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        description = "allow openSSH"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        description = "all protocols in egress direction"
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
      Name = "codepipeline-SG"
    }
}
# create Ubuntu webserver
# create elastic IP address
# create webserver NIC
resource "aws_network_interface" "webserver-NIC" {
    subnet_id = aws_subnet.codepipeline-PUB.id
    private_ips = ["10.10.0.25"]
    security_groups = [aws_security_group.codepipeline-SG.id]
    
    tags = {
      Name = "webserver-NIC"
    }
}
resource "aws_eip" "webserver-IP" {
    vpc = true
    network_interface = aws_network_interface.webserver-NIC.id
    associate_with_private_ip = "10.10.0.25"
    depends_on = [aws_internet_gateway.codepipeline-IGW]  
}
resource "aws_instance" "Ubuntu-webserver" {
    ami = "ami-0015a39e4b7c0966f"
    instance_type = "t2.micro"
    availability_zone = "eu-west-2a"
    key_name = "aws-codepipeline-main-key"

    network_interface {
        device_index = 0
        network_interface_id = aws_network_interface.webserver-NIC.id
    }

    user_data = <<-EOF
        #!/bin/bash
        sudo apt update -y
        sudo apt install apache2 -y
        sudo systemctl start apache2
        sudo bash -c 'echo **** MY FIRST WEBSERVER HelloWorld **** > /var/www/htm/index.html'
    EOF
    tags = {
       Name = "Ubuntu-webserver"
    }
}

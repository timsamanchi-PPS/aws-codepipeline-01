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
    
    enable_dns_hostnames = true
    enable_dns_support = true

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
# associuate it with cutom IGW route table
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

# Define your AWS provider configuration
provider "aws" {
  region = "ap-south-1" # Update with your desired AWS region
}

# Variables
variable "elasticapp" {
  default = "YourElasticBeanstalkApp"
}

variable "beanstalkappenv" {
  default = "YourElasticBeanstalkEnv"
}

variable "tier" {
  default = "WebServer"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16" # Update with your desired VPC CIDR block
}

variable "public_subnet_cidrs" {
  default = ["10.0.1.0/24", "10.0.2.0/24"] # Update with your desired public subnet CIDR blocks
}

variable "private_subnet_cidrs" {
  default = ["10.0.3.0/24", "10.0.4.0/24"] # Update with your desired private subnet CIDR blocks
}

# Create a custom VPC
resource "aws_vpc" "custom_vpc" {
  cidr_block = var.vpc_cidr
}

# Create public subnets
resource "aws_subnet" "public_subnets" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.custom_vpc.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = true
  description = "ebs-public-subnet"
}

# Create private subnets
resource "aws_subnet" "private_subnets" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.custom_vpc.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  description = "ebs-private-subnet"
}

# Create an Internet Gateway and associate it with the VPC
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.custom_vpc.id
  description = "ebs-internetgateway"
}

# Create a route table for public subnets and associate it with the Internet Gateway
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.custom_vpc.id
  description = "ebs-rt-public"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# Associate public subnets with the public route table
resource "aws_route_table_association" "public_subnet_association" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_route_table.id
  description = "ebs-public-subnet-rt"
}

# Create an Elastic IP for the NAT Gateway
resource "aws_eip" "nat_eip" {}

# Create a security group for Elastic Beanstalk instances (customize as needed)
resource "aws_security_group" "eb_security_group" {
  name        = "eb_security_group"
  description = "Security group for Elastic Beanstalk instances"

  # Define your security group rules here
  # For example, allow HTTP and SSH traffic:
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create a NAT Gateway in a public subnet and associate the Elastic IP
resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnets[0].id # Use one of your public subnets
  description = "ebs-NATGateway"
}

# Data source to fetch availability zones in the selected region
data "aws_availability_zones" "available" {}

# Create an S3 bucket to store your application code
resource "aws_s3_bucket" "elasticbeanstalk_bucket" {
  bucket = "beanstalk-tf-bucket"
  acl    = "private"
}

# Upload your application code to the S3 bucket
resource "aws_s3_bucket_object" "code_upload" {
  bucket       = aws_s3_bucket.elasticbeanstalk_bucket.id
  key          = "swf.zip"
  source       = "D:\\SWF_Project\\swf.zip"
  content_type = "application/zip"
}

# Create an Elastic Beanstalk application
resource "aws_elastic_beanstalk_application" "example" {
  name        = "dotnet-core-ebs-tf-app"
  description = "Your .NET Core Application"
}

# Create an Elastic Beanstalk application version
resource "aws_elastic_beanstalk_application_version" "example" {
  name        = "v1"
  application = aws_elastic_beanstalk_application.example.name
  description = "Your .NET Core Application Version"
  bucket      = aws_s3_bucket.elasticbeanstalk_bucket.id
  key         = aws_s3_bucket_object.code_upload.key
}

# Create an Elastic Beanstalk environment
resource "aws_elastic_beanstalk_environment" "example" {
  name                   = "dotnet-core-ebs-tf"
  application            = aws_elastic_beanstalk_application.example.name
  solution_stack_name    = "64bit Amazon Linux 2 v2.5.7 running .NET Core"
  wait_for_ready_timeout = "15m"
  version_label          = aws_elastic_beanstalk_application_version.example.name

  setting {
    namespace = "aws:ec2:vpc"
    name      = "VPCId"
    value     = aws_vpc.custom_vpc.id
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = "aws-elasticbeanstalk-ec2-role"
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "AssociatePublicIpAddress"
    value     = "True"
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "Subnets"
    value     = join(",", aws_subnet.public_subnets[*].id)
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment:process:default"
    name      = "MatcherHTTPCode"
    value     = "200"
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "LoadBalancerType"
    value     = "application"
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "InstanceType"
    value     = "t2.small"
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "ELBScheme"
    value     = "internet-facing"
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MinSize"
    value     = 1
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value     = 2
  }

  setting {
    namespace = "aws:elasticbeanstalk:healthreporting:system"
    name      = "SystemType"
    value     = "enhanced"
  }
}

provider "aws" {
  region = "us-east-1" # Change to your desired region
}

# Create a VPC with a name tag
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "MyVPC"
  }
}

# Create two availability zones
data "aws_availability_zones" "available" {}

# Create public and private subnets
resource "aws_subnet" "public_subnet" {
  count                   = 2
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.${count.index}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "PublicSubnet-${count.index + 1}"
  }
}

resource "aws_subnet" "private_subnet" {
  count             = 2
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.${count.index + 10}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "PrivateSubnet-${count.index + 1}"
  }
}

# Create an internet gateway with a name tag
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "MyInternetGateway"
  }
}

# Create a NAT gateway with an Elastic IP
resource "aws_eip" "my_eip" {
  instance = null
}

resource "aws_nat_gateway" "my_nat_gateway" {
  allocation_id = aws_eip.my_eip.id
  subnet_id     = aws_subnet.public_subnet[0].id
}

# Create a public route table for public subnets with Internet Gateway
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "PublicRouteTable"
  }
}
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "PrivateRouteTable"
  }
}

# Create route entries for public route table (Internet Gateway)
resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.my_igw.id
}

# Create route entries for private route table with NAT Gateway
resource "aws_route" "private_route" {
  route_table_id         = aws_route_table.private_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.my_nat_gateway.id
}

# Set the public route table as the main route table for the VPC
resource "aws_main_route_table_association" "public_main_route_table_association" {
  vpc_id         = aws_vpc.my_vpc.id
  route_table_id = aws_route_table.public_route_table.id
}

# Explicit subnet associations for public route table
resource "aws_route_table_association" "public_subnet_association" {
  count          = 2
  subnet_id      = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.public_route_table.id
}

# Explicit subnet associations for private route table
resource "aws_route_table_association" "private_subnet_association" {
  count          = 2
  subnet_id      = aws_subnet.private_subnet[count.index].id
  route_table_id = aws_route_table.private_route_table.id
}


# Create Elastic Beanstalk application, version, and environment (as previously defined)

# Create a security group for Elastic Beanstalk
resource "aws_security_group" "eb_security_group" {
  name_prefix = "eb_security_group_"
  description = "Elastic Beanstalk Security Group"

  # Define your security group rules here, e.g., for incoming traffic
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow outbound traffic to the internet
  }

  # Add more rules as needed for your application

  vpc_id = aws_vpc.my_vpc.id
}

# Create an S3 bucket to store your application code
resource "aws_s3_bucket" "elasticbeanstalk_bucket" {
  bucket = "beanstalk-tf-bucket" # add your bucket name 
  acl    = "private"
}

# Upload your application code to the S3 bucket
resource "aws_s3_bucket_object" "code_upload" {
  bucket       = aws_s3_bucket.elasticbeanstalk_bucket.id
  key          = "ebs.zip" #add filename in zip format
  source       = "D:\\elasticbeanstalk_Project\\ebs.zip"  #add path to your local 
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

# Update the Elastic Beanstalk environment to use the security group and public route table
resource "aws_elastic_beanstalk_environment" "example" {
  name                   = "dotnet-core-ebs-tf"
  application            = aws_elastic_beanstalk_application.example.name
  solution_stack_name    = "64bit Amazon Linux 2 v2.5.7 running .NET Core" #select the solution name shown in your region
  wait_for_ready_timeout = "15m"
  version_label          = aws_elastic_beanstalk_application_version.example.name

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = "aws-elasticbeanstalk-ec2-role"
  }
  setting {
    namespace = "aws:ec2:vpc"
    name      = "AssociatePublicIpAddress"
    value     = "false"
  }
  # Configure subnets for the Elastic Beanstalk environment
  setting {
    namespace = "aws:ec2:vpc"
    name      = "ELBSubnets"
    value     = join(",", [aws_subnet.public_subnet[0].id, aws_subnet.public_subnet[1].id])
  }
  setting {
    namespace = "aws:ec2:vpc"
    name      = "Subnets"
    value     = join(",", [aws_subnet.private_subnet[0].id, aws_subnet.private_subnet[1].id])
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment:process:HTTPS"
    name      = "MatcherHTTPCode"
    value     = "200"
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "LoadBalancerType"
    value     = "application"
  }

  # Assign the security group for Elastic Beanstalk to restrict access
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "SecurityGroups"
    value     = aws_security_group.eb_security_group.id
  }

  # Add the HTTPS listener and SSL certificate configuration
  setting {
    namespace = "aws:elbv2:listener:443"
    name      = "ListenerEnabled"
    value     = "true"
  }

  setting {
    namespace = "aws:elbv2:listener:443"
    name      = "Protocol"
    value     = "HTTPS"
  }

  setting {
    namespace = "aws:elbv2:listener:443"
    name      = "SSLCertificateArns"
    value     = "arn:aws:acm:us-east-1:515304497950:certificate/b30eaad8-784d-4f2f-7d5e-6323424342f" # Replace with your SSL certificate ARN
  }

  # Add the SSL policy
  setting {
    namespace = "aws:elbv2:listener:443"
    name      = "SSLPolicy"
    value     = "ELBSecurityPolicy-TLS-1-2-Ext-2018-06"
  }

  # Set Load Balancer network settings
  setting {
    namespace = "aws:ec2:vpc"
    name      = "ELBScheme"
    value     = "internet-facing" # Set to "internet-facing" for public, "internal" for internal
  }

  # Configure processes
  setting {
    namespace = "aws:elasticbeanstalk:environment:process:HTTPS"
    name      = "Port"
    value     = "443"
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment:process:HTTPS"
    name      = "Protocol"
    value     = "HTTPS"
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

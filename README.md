# create elastic beanstalk using terraform script

# Elastic Beanstalk Infrastructure with VPC, Subnets, and Elastic Beanstalk Environment

This Terraform script creates an AWS infrastructure for an Elastic Beanstalk environment with a custom VPC, public and private subnets, and associated resources.

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) installed on your local machine.
- AWS credentials configured with appropriate permissions.

## How to Use

1. Clone the repository to your local machine:

   ```bash
   git clone <repository-url>

# Navigate to the project directory:
cd <project-directory>
Update the main.tf file with your desired AWS region and other configuration settings.

# Initialize Terraform:
terraform init

# Review the changes that will be applied:
terraform plan

# Apply the changes to create the infrastructure:
terraform apply

Confirm with yes when prompted.

After the infrastructure is created, review the output for information such as the Elastic Beanstalk environment URL.

# To destroy the infrastructure when it is no longer needed:
terraform destroy

Confirm with yes when prompted.

# Structure
main.tf: Defines the main Terraform configuration.

variables.tf: Contains variable definitions.

outputs.tf: Specifies the output variables.

README.md: Provides instructions and information about the project.

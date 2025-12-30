#--------------------------------------------------------------
# Terraform Backend Configuration
# 
# Before using this backend, create the S3 bucket and DynamoDB table:
#
# aws s3 mb s3://your-terraform-state-bucket --region us-east-1
#
# aws dynamodb create-table \
#     --table-name terraform-state-lock \
#     --attribute-definitions AttributeName=LockID,AttributeType=S \
#     --key-schema AttributeName=LockID,KeyType=HASH \
#     --billing-mode PAY_PER_REQUEST
#--------------------------------------------------------------

# Uncomment the below block after creating S3 bucket and DynamoDB table
# terraform {
#   backend "s3" {
#     bucket         = "your-terraform-state-bucket"
#     key            = "eks-cicd/terraform.tfstate"
#     region         = "us-east-1"
#     encrypt        = true
#     dynamodb_table = "terraform-state-lock"
#   }
# }

# Using local backend for development
# Comment this out when using S3 backend
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}

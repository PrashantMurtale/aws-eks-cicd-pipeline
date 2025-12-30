#--------------------------------------------------------------
# AWS EKS CI/CD Infrastructure
# Main Terraform Configuration
#--------------------------------------------------------------

locals {
  name_prefix = "${var.project_name}-${var.environment}"
  
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

#--------------------------------------------------------------
# VPC Module
#--------------------------------------------------------------
module "vpc" {
  source = "./modules/vpc"

  name_prefix          = local.name_prefix
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  
  tags = local.common_tags
}

#--------------------------------------------------------------
# EKS Module
#--------------------------------------------------------------
module "eks" {
  source = "./modules/eks"

  name_prefix         = local.name_prefix
  cluster_version     = var.eks_cluster_version
  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  
  node_instance_types = var.eks_node_instance_types
  desired_capacity    = var.eks_desired_capacity
  min_capacity        = var.eks_min_capacity
  max_capacity        = var.eks_max_capacity
  disk_size           = var.eks_disk_size

  tags = local.common_tags

  depends_on = [module.vpc]
}

#--------------------------------------------------------------
# ECR Module
#--------------------------------------------------------------
module "ecr" {
  source = "./modules/ecr"

  name_prefix          = local.name_prefix
  repository_names     = var.ecr_repository_names
  image_tag_mutability = var.ecr_image_tag_mutability
  scan_on_push         = var.ecr_scan_on_push

  tags = local.common_tags
}

#--------------------------------------------------------------
# IAM Module
#--------------------------------------------------------------
module "iam" {
  source = "./modules/iam"

  name_prefix      = local.name_prefix
  eks_cluster_name = module.eks.cluster_name
  oidc_provider    = module.eks.oidc_provider
  oidc_provider_arn = module.eks.oidc_provider_arn

  tags = local.common_tags

  depends_on = [module.eks]
}

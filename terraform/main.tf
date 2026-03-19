terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_availability_zones" "available" {}

# 1. Cost-Optimized VPC (Public Subnets Only to avoid NAT Gateway charges)
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "seyoawe-vpc"
  cidr = "10.0.0.0/16"
  azs  = slice(data.aws_availability_zones.available.names, 0, 2)
  
  public_subnets          = ["10.0.1.0/24", "10.0.2.0/24"]
  map_public_ip_on_launch = true # Required for public node groups

  # Explicitly disable NAT Gateways to save $32/month
  enable_nat_gateway = false
  single_nat_gateway = false
}

# 2. Amazon EKS Cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "seyoawe-cluster"
  cluster_version = "1.30"

  # Allow Jenkins and kubectl to connect to the cluster over the internet
  cluster_endpoint_public_access = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets # Deploying nodes to public subnets

  eks_managed_node_groups = {
    standard_nodes = {
      min_size     = 1
      max_size     = 2
      desired_size = 2

      # t3.micro cannot hold enough pods. t3.medium is the minimum viable for monitoring.
      instance_types = ["t3.medium"] 
      
      # Required when nodes are in public subnets
      associate_public_ip_address = true
    }
  }
}

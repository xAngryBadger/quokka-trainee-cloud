# NOTA DE TREINAMENTO: Este projeto usa a VPC default da AWS (data "aws_vpc" "default").
# Em producao, isso e inseguro. Um projeto real exigiria:
# - Criacao de VPC dedicada com aws_vpc
# - Subnets privadas para ECS tasks
# - NAT Gateway para saida de internet
# - VPC endpoints para ECR, S3, CloudWatch
# Esta escolha e intencional para escopo de trainee - foca em CI/CD e IaC,
# mas NAO deve ser replicada em ambientes de producao.

terraform {
  required_version = ">= 1.5.0"
  
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "terraform-state-trainee"
    key = "ecs/terraform.tfstate"
    region = "us-east-1"
    dynamodb_table = "terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project = "trainee-devops-api"
      Environment = var.environment
      ManagedBy = "terraform"
    }
  }
}
  }

  backend "s3" {
    bucket         = "terraform-state-trainee"
    key            = "ecs/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "trainee-devops-api"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

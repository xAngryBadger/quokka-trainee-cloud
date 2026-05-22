variable "aws_region" {
  description = "Regiao AWS para deploy dos recursos"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Ambiente de deploy (dev, staging, production)"
  type        = string
  default     = "production"
}

variable "app_name" {
  description = "Nome da aplicacao"
  type        = string
  default     = "trainee-devops-api"
}

variable "container_image" {
  description = "Imagem Docker para o container ECS (com tag)"
  type        = string
  default     = "registry.gitlab.com/trainee-cloud-ia/trainee-devops-api:latest"
}

variable "container_port" {
  description = "Porta exposta pelo container"
  type        = number
  default     = 5000
}

variable "cpu" {
  description = "Unidades de CPU para o task definition (1 vCPU = 1024)"
  type        = number
  default     = 256
}

variable "memory" {
  description = "Memoria (MiB) para o task definition"
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Numero de tarefas ECS desejadas"
  type        = number
  default     = 2
}

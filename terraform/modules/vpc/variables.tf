variable "region" {
  description = "AWS region"
  type        = string
}

variable "project_name" {
  description = "Project name for resource tagging"
  type        = string
  default     = "cloudpulse"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "cluster_name" {
  description = "EKS cluster name — used for Kubernetes subnet discovery tags"
  type        = string
  default     = "cloudpulse-cluster"
}

variable "tags" {
  description = "Common tags merged into every resource"
  type        = map(string)
  default     = {}
}

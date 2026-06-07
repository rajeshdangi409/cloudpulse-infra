variable "subnet_ids" {
  description = "All subnet IDs for EKS control plane"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for EKS worker nodes"
  type        = list(string)
}

variable "vpc_id" {
  description = "VPC ID where EKS will be deployed"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "cloudpulse-cluster"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster (pinned for reproducibility)"
  type        = string
  default     = "1.31"
}

variable "node_instance_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
  default     = "t3.small"
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 3
}

variable "project_name" {
  description = "Project name for resource tagging"
  type        = string
  default     = "cloudpulse"
}

variable "tags" {
  description = "Common tags merged into every resource"
  type        = map(string)
  default     = {}
}

variable "ecr_repo_name" {
  description = "ECR repository name"
  type        = string
  default     = "cloudpulse-app"
}

variable "tags" {
  description = "Common tags merged into every resource"
  type        = map(string)
  default     = {}
}
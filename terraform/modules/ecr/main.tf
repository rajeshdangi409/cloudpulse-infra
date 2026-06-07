resource "aws_ecr_repository" "app" {
  name         = var.ecr_repo_name
  force_delete = true
  tags         = merge(var.tags, { Name = var.ecr_repo_name })
}


output "role_arn" {
  description = "ARN of the GitHub Actions Terraform IAM role."
  value       = aws_iam_role.terraform.arn
}

output "role_name" {
  description = "Name of the GitHub Actions Terraform IAM role."
  value       = aws_iam_role.terraform.name
}

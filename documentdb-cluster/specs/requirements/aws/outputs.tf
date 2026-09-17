output "permissions_role_arn" {
  description = "ARN of the DocumentDB permissions role assumed by the nullplatform agent role. Pass to the agent (assume_role_arns) and publish to the AWS IAM provider (selector \"documentdb-cluster\")."
  value       = local.iam_create ? aws_iam_role.nullplatform_documentdb[0].arn : ""
}

output "permissions_role_name" {
  description = "Name of the DocumentDB permissions role"
  value       = local.iam_create ? aws_iam_role.nullplatform_documentdb[0].name : ""
}

output "permissions_role_id" {
  description = "ID of the DocumentDB permissions role"
  value       = local.iam_create ? aws_iam_role.nullplatform_documentdb[0].id : ""
}

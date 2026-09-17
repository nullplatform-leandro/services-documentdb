################################################################################
# documentdb-database service — assume-role IAM
#
# This service creates NO AWS infrastructure. It reaches into a cluster that
# documentdb-cluster already provisioned and creates one database inside it over
# the MongoDB wire protocol. So its permissions are deliberately much narrower
# than the cluster service's: read the master secret, and manage its own
# Terraform state. No rds:*, no ec2:*, no kms:*.
#
# It still needs its own role rather than sharing the cluster's: a namespace may
# grant teams the ability to create databases without granting them the ability
# to create, resize or destroy clusters.
################################################################################

resource "aws_iam_role" "nullplatform_documentdb_database" {
  count = local.iam_create ? 1 : 0

  name        = local.role_name
  description = "Permissions role assumed by the nullplatform agent role for the documentdb-database service"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = concat([local.agent_role_arn], var.additional_agent_role_arns) }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.iam_default_tags
}

# --- Secrets Manager (read only) ----------------------------------------------
# The service never writes the master secret — documentdb-cluster owns it. It
# only reads it, on every action including destroy, to authenticate to the
# cluster as the master user.
resource "aws_iam_policy" "nullplatform_documentdb_database_secrets" {
  count = local.iam_create ? 1 : 0

  name        = "${local.policies_name_prefix}_documentdb_database_secrets_policy"
  description = "Read-only access to the DocumentDB master credentials secrets owned by the cluster service"
  tags        = local.iam_default_tags

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue"
        ],
        "Resource" : "arn:aws:secretsmanager:*:*:secret:nullplatform/documentdb/*"
      },
      {
        "Effect" : "Allow",
        "Action" : ["secretsmanager:ListSecrets"],
        "Resource" : "*"
      }
    ]
  })
}

# --- Terraform state ----------------------------------------------------------
resource "aws_iam_policy" "nullplatform_documentdb_database_tfstate" {
  count = local.iam_create ? 1 : 0

  name        = "${local.policies_name_prefix}_documentdb_database_tfstate_policy"
  description = "Policy for the per-instance S3 buckets holding this service's Terraform state"
  tags        = local.iam_default_tags

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:CreateBucket",
          "s3:DeleteBucket",
          "s3:ListBucket",
          "s3:ListBucketVersions",
          "s3:GetBucketVersioning",
          "s3:PutBucketVersioning",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:DeleteObjectVersion"
        ],
        "Resource" : [
          "arn:aws:s3:::np-service-*",
          "arn:aws:s3:::np-service-*/*"
        ]
      }
    ]
  })
}

# --- Attachments --------------------------------------------------------------

resource "aws_iam_role_policy_attachment" "secrets" {
  count = local.iam_create ? 1 : 0

  role       = aws_iam_role.nullplatform_documentdb_database[0].name
  policy_arn = aws_iam_policy.nullplatform_documentdb_database_secrets[0].arn
}

resource "aws_iam_role_policy_attachment" "tfstate" {
  count = local.iam_create ? 1 : 0

  role       = aws_iam_role.nullplatform_documentdb_database[0].name
  policy_arn = aws_iam_policy.nullplatform_documentdb_database_tfstate[0].arn
}

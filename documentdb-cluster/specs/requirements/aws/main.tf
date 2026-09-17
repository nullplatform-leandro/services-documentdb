################################################################################
# documentdb-cluster service — assume-role IAM
#
# The service operates AWS through the ASSUME-ROLE pattern: this dedicated role
# holds the permissions, and the nullplatform agent assumes it (sts:AssumeRole).
# The consuming stack passes this role's ARN to the agent (assume_role_arns) and
# publishes it to the nullplatform AWS IAM provider under the selector
# "documentdb-cluster".
#
# The role trusts the agent role BY NAME (derived default) rather than through a
# module output, so the consuming stack can wire the ARN back into the agent
# without creating a dependency cycle.
################################################################################

resource "aws_iam_role" "nullplatform_documentdb" {
  count = local.iam_create ? 1 : 0

  name        = local.role_name
  description = "Permissions role assumed by the nullplatform agent role for the documentdb-cluster service"

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

# --- DocumentDB cluster management --------------------------------------------
# DocumentDB has no IAM namespace of its own: every call is an "rds:*" action.
# That is not a copy-paste slip from the RDS service — rds:CreateDBCluster is
# genuinely how a DocumentDB cluster is created, and a policy written against a
# "docdb:" prefix grants nothing at all.
resource "aws_iam_policy" "nullplatform_documentdb" {
  count = local.iam_create ? 1 : 0

  name        = "${local.policies_name_prefix}_documentdb_policy"
  description = "Policy for managing DocumentDB clusters provisioned by the documentdb-cluster service"
  tags        = local.iam_default_tags

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "DocumentDBCluster",
        "Effect" : "Allow",
        "Action" : [
          "rds:CreateDBCluster",
          "rds:DeleteDBCluster",
          "rds:ModifyDBCluster",
          "rds:DescribeDBClusters",
          "rds:CreateDBInstance",
          "rds:DeleteDBInstance",
          "rds:ModifyDBInstance",
          "rds:DescribeDBInstances",
          "rds:CreateDBSubnetGroup",
          "rds:DeleteDBSubnetGroup",
          "rds:ModifyDBSubnetGroup",
          "rds:DescribeDBSubnetGroups",
          "rds:CreateDBClusterParameterGroup",
          "rds:DeleteDBClusterParameterGroup",
          "rds:ModifyDBClusterParameterGroup",
          "rds:DescribeDBClusterParameterGroups",
          "rds:DescribeDBClusterParameters",
          "rds:DescribeDBEngineVersions",
          "rds:DescribeDBClusterSnapshots",
          "rds:DeleteDBClusterSnapshot",
          "rds:AddTagsToResource",
          "rds:RemoveTagsFromResource",
          "rds:ListTagsForResource"
        ],
        "Resource" : "*"
      }
    ]
  })
}

# --- Networking ---------------------------------------------------------------
# The service creates one security group per cluster and reads the VPC's CIDR
# associations and the private subnets to build the subnet group.
resource "aws_iam_policy" "nullplatform_documentdb_network" {
  count = local.iam_create ? 1 : 0

  name        = "${local.policies_name_prefix}_documentdb_network_policy"
  description = "Policy for the security group and VPC/subnet lookups the documentdb-cluster service performs"
  tags        = local.iam_default_tags

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "SecurityGroups",
        "Effect" : "Allow",
        "Action" : [
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:CreateTags",
          "ec2:DeleteTags"
        ],
        "Resource" : "*"
      },
      {
        "Sid" : "NetworkDiscovery",
        "Effect" : "Allow",
        "Action" : [
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSecurityGroupRules",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeTags"
        ],
        "Resource" : "*"
      }
    ]
  })
}

# --- Secrets Manager ----------------------------------------------------------
# GetSecretValue is not optional and not an oversight: link actions re-read the
# master credentials on every run, including unlink, because a destroy-time
# provisioner can carry the secret's ARN but never the password itself.
resource "aws_iam_policy" "nullplatform_documentdb_secrets" {
  count = local.iam_create ? 1 : 0

  name        = "${local.policies_name_prefix}_documentdb_secrets_policy"
  description = "Policy for the Secrets Manager secret holding DocumentDB master credentials"
  tags        = local.iam_default_tags

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "secretsmanager:CreateSecret",
          "secretsmanager:DeleteSecret",
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecret",
          "secretsmanager:TagResource",
          "secretsmanager:UntagResource",
          "secretsmanager:ListSecretVersionIds"
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

# --- KMS ----------------------------------------------------------------------
# The cluster is created with storage_encrypted = true, which makes RDS request
# a grant on the AWS-managed key. Without CreateGrant/DescribeKey the create
# fails with KMSKeyNotAccessibleFault — a message that names the key, not the
# missing permission, and sends people looking in the wrong place.
resource "aws_iam_policy" "nullplatform_documentdb_kms" {
  count = local.iam_create ? 1 : 0

  name        = "${local.policies_name_prefix}_documentdb_kms_policy"
  description = "Policy for the KMS grant DocumentDB storage encryption requires"
  tags        = local.iam_default_tags

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "kms:CreateGrant",
          "kms:DescribeKey",
          "kms:ListAliases",
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:GenerateDataKeyWithoutPlaintext",
          "kms:ReEncryptFrom",
          "kms:ReEncryptTo"
        ],
        "Resource" : "*"
      }
    ]
  })
}

# --- Terraform state ----------------------------------------------------------
# build_context creates one bucket per service instance (np-service-<id>) and
# delete_tfstate_bucket empties and removes it on delete.
resource "aws_iam_policy" "nullplatform_documentdb_tfstate" {
  count = local.iam_create ? 1 : 0

  name        = "${local.policies_name_prefix}_documentdb_tfstate_policy"
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

# --- Attach every policy to the assume-role -----------------------------------

resource "aws_iam_role_policy_attachment" "documentdb" {
  count = local.iam_create ? 1 : 0

  role       = aws_iam_role.nullplatform_documentdb[0].name
  policy_arn = aws_iam_policy.nullplatform_documentdb[0].arn
}

resource "aws_iam_role_policy_attachment" "documentdb_network" {
  count = local.iam_create ? 1 : 0

  role       = aws_iam_role.nullplatform_documentdb[0].name
  policy_arn = aws_iam_policy.nullplatform_documentdb_network[0].arn
}

resource "aws_iam_role_policy_attachment" "documentdb_secrets" {
  count = local.iam_create ? 1 : 0

  role       = aws_iam_role.nullplatform_documentdb[0].name
  policy_arn = aws_iam_policy.nullplatform_documentdb_secrets[0].arn
}

resource "aws_iam_role_policy_attachment" "documentdb_kms" {
  count = local.iam_create ? 1 : 0

  role       = aws_iam_role.nullplatform_documentdb[0].name
  policy_arn = aws_iam_policy.nullplatform_documentdb_kms[0].arn
}

resource "aws_iam_role_policy_attachment" "documentdb_tfstate" {
  count = local.iam_create ? 1 : 0

  role       = aws_iam_role.nullplatform_documentdb[0].name
  policy_arn = aws_iam_policy.nullplatform_documentdb_tfstate[0].arn
}

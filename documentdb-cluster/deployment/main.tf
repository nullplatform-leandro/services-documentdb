locals {
  # The cluster parameter group family tracks the engine's major version.
  # Getting this wrong is an apply-time AWS error, not a plan-time one.
  parameter_group_family = "docdb${split(".", var.engine_version)[0]}.${split(".", var.engine_version)[1]}"

  common_tags = {
    "managed-by" = "nullplatform"
    "service-id" = var.service_id
  }
}

# ---------------------------------------------------------------------------
# Security group — allows MongoDB wire protocol from inside the VPC
# ---------------------------------------------------------------------------

resource "aws_security_group" "docdb" {
  name        = "np-docdb-${var.instance_name}"
  description = "Allow DocumentDB access from within the VPC"
  vpc_id      = var.vpc_id

  ingress {
    from_port = 27017
    to_port   = 27017
    protocol  = "tcp"
    # Every CIDR associated with the VPC, not just the primary one. EKS clusters
    # commonly add a secondary CIDR for pod networking (a 100.64.x.x block next
    # to the primary 10.x.x.x one) and pods draw their IPs from it — restricting
    # to the primary CIDR silently blocks the agent, and every link then hangs
    # until mongosh times out rather than failing with anything readable.
    cidr_blocks = [for c in data.aws_vpc.main.cidr_block_associations : c.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# Master credentials — generated here, stored in Secrets Manager
#
# The link actions re-read this secret with the AWS CLI on every run rather
# than receiving the password as a Terraform variable. That is deliberate: a
# destroy-time provisioner may only reference `self`, never `var`, so the
# unlink path has no way to be handed the password. See scripts/aws/mongo_user.sh.
# ---------------------------------------------------------------------------

resource "random_password" "master" {
  length = 32
  # DocumentDB rejects / " and @ in the master password, and the password also
  # ends up percent-encoded into a mongodb:// URI. Alphanumeric sidesteps both.
  special = false
}

resource "aws_secretsmanager_secret" "master" {
  name                    = "nullplatform/documentdb/${var.instance_name}/master"
  recovery_window_in_days = 0

  tags = merge(local.common_tags, {
    "docdb-cluster" = var.instance_name
  })
}

resource "aws_secretsmanager_secret_version" "master" {
  secret_id = aws_secretsmanager_secret.master.id
  secret_string = jsonencode({
    username = "npmaster"
    password = random_password.master.result
  })
}

# ---------------------------------------------------------------------------
# Cluster
# ---------------------------------------------------------------------------

resource "aws_docdb_subnet_group" "main" {
  name       = var.instance_name
  subnet_ids = data.aws_subnets.private.ids

  tags = local.common_tags
}

resource "aws_docdb_cluster_parameter_group" "main" {
  name        = var.instance_name
  family      = local.parameter_group_family
  description = "Cluster parameters for nullplatform DocumentDB ${var.instance_name}"

  # TLS is on by default and stays on. Turning it off would let clients connect
  # without the RDS CA bundle, which is convenient and wrong.
  parameter {
    name  = "tls"
    value = "enabled"
  }

  tags = local.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_docdb_cluster" "main" {
  cluster_identifier = var.instance_name
  engine             = "docdb"
  engine_version     = var.engine_version

  master_username = "npmaster"
  master_password = random_password.master.result

  db_subnet_group_name            = aws_docdb_subnet_group.main.name
  db_cluster_parameter_group_name = aws_docdb_cluster_parameter_group.main.name
  vpc_security_group_ids          = [aws_security_group.docdb.id]

  port                = 27017
  storage_encrypted   = true
  storage_type        = "standard"
  apply_immediately   = true
  deletion_protection = var.deletion_protection

  backup_retention_period      = var.backup_retention_period
  preferred_backup_window      = var.preferred_backup_window
  preferred_maintenance_window = var.preferred_maintenance_window

  skip_final_snapshot = true

  tags = local.common_tags

  depends_on = [aws_secretsmanager_secret_version.master]
}

resource "aws_docdb_cluster_instance" "main" {
  count = var.instance_count

  identifier         = "${var.instance_name}-${count.index}"
  cluster_identifier = aws_docdb_cluster.main.id
  instance_class     = var.instance_class
  apply_immediately  = true

  tags = local.common_tags
}

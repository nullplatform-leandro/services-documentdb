# Shared networking, discovered from the VPC that build_context resolved out of
# the nullplatform aws-networking-configuration provider.

data "aws_vpc" "main" {
  id = var.vpc_id
}

# The subnet group is built from subnets tagged by nullplatform during setup.
# DocumentDB has no public endpoint, so these are always the private ones — a
# cluster placed in public subnets is still unreachable from the internet, just
# harder to reason about.
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
  tags = {
    "nullplatform/subnet-type" = "private"
  }
}

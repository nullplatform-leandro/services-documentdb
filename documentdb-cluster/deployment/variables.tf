variable "service_id" {
  type        = string
  description = "Nullplatform service ID"
}

variable "instance_name" {
  type        = string
  description = "Unique instance name for AWS resource naming (format: np-<sanitized service name>)"
}

variable "region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region"
}

variable "vpc_id" {
  type        = string
  description = "VPC the cluster is deployed into. DocumentDB is VPC-only; there is no public endpoint."
}

variable "instance_class" {
  type        = string
  default     = "db.t3.medium"
  description = "Instance class for every cluster member"
}

variable "instance_count" {
  type        = number
  default     = 1
  description = "Number of instances in the cluster (first is the writer, rest are read replicas)"

  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 6
    error_message = "instance_count must be between 1 and 6"
  }
}

variable "engine_version" {
  type        = string
  default     = "5.0.0"
  description = "DocumentDB engine version"

  validation {
    condition     = contains(["4.0.0", "5.0.0", "8.0.0"], var.engine_version)
    error_message = "engine_version must be one of: 4.0.0, 5.0.0, 8.0.0"
  }
}

variable "backup_retention_period" {
  type        = number
  default     = 7
  description = "Days of automated backups to retain (DocumentDB minimum is 1)"

  validation {
    condition     = var.backup_retention_period >= 1 && var.backup_retention_period <= 35
    error_message = "backup_retention_period must be between 1 and 35 — DocumentDB has no zero-retention mode"
  }
}

variable "preferred_backup_window" {
  type        = string
  default     = "03:00-04:00"
  description = "Daily backup window in UTC (hh:mm-hh:mm)"
}

variable "preferred_maintenance_window" {
  type        = string
  default     = "Mon:04:00-Mon:05:00"
  description = "Weekly maintenance window in UTC (ddd:hh:mm-ddd:hh:mm)"
}

variable "deletion_protection" {
  type        = bool
  default     = false
  description = "Block cluster deletion at the AWS API level"
}

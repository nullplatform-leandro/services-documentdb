variable "link_id" {
  type        = string
  description = "Nullplatform link ID. Doubles as the keeper that stabilises the generated password across re-applies."
}

variable "region" {
  type        = string
  description = "AWS region holding the master credentials secret"
}

variable "docdb_host" {
  type        = string
  description = "Cluster writer endpoint"
}

variable "docdb_port" {
  type        = number
  default     = 27017
  description = "Cluster port"
}

variable "db_name" {
  type        = string
  description = "Database this link is scoped to"
}

variable "mongo_username" {
  type        = string
  description = "MongoDB username to provision, derived from the link ID"
}

variable "master_secret_arn" {
  type        = string
  description = "Secrets Manager ARN of the cluster master credentials. Travels through the null_resource triggers so the destroy-time provisioner can reach it — a destroy provisioner may only reference self."
}

variable "access_level" {
  type        = string
  default     = "read-write"
  description = "Permission level: read, write, or read-write"

  validation {
    condition     = contains(["read", "write", "read-write"], var.access_level)
    error_message = "access_level must be one of: read, write, read-write"
  }
}

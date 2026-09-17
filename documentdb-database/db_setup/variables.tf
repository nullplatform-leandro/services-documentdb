variable "service_id" {
  type        = string
  description = "Nullplatform service ID"
}

variable "region" {
  type        = string
  description = "AWS region holding the hosting cluster's master credentials secret"
}

variable "docdb_host" {
  type        = string
  description = "Writer endpoint of the hosting cluster"
}

variable "docdb_port" {
  type        = number
  default     = 27017
  description = "Cluster port"
}

variable "db_name" {
  type        = string
  description = "Database this service owns"
}

variable "master_secret_arn" {
  type        = string
  description = "Secrets Manager ARN of the hosting cluster's master credentials. Travels through the null_resource triggers so the destroy-time provisioner can reach it."
}

variable "drop_on_delete" {
  type        = bool
  default     = false
  description = "Whether destroying this service also drops the database and its data. Default false: removing the service leaves the data recoverable."
}

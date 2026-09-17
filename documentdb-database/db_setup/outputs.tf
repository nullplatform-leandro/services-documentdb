output "database_name" {
  value       = var.db_name
  description = "Database this service owns"
  depends_on  = [null_resource.database]
}

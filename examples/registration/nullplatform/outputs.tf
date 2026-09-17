# Consumed by nullplatform-bindings/ through terraform_remote_state. The
# binding needs the slug the API actually assigned, not the one in the template.

output "documentdb_cluster_service_specification_slug" {
  value       = module.service_definition_documentdb_cluster.service_specification_slug
  description = "Slug of the registered documentdb-cluster service specification"
}

output "documentdb_database_service_specification_slug" {
  value       = module.service_definition_documentdb_database.service_specification_slug
  description = "Slug of the registered documentdb-database service specification"
}

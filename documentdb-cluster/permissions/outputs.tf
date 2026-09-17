output "username" {
  value       = var.mongo_username
  description = "MongoDB username created for this link"
  depends_on  = [null_resource.mongo_user]
}

output "password" {
  value       = random_password.user.result
  sensitive   = true
  description = "Password for that user"
  depends_on  = [null_resource.mongo_user]
}

output "database_name" {
  value       = var.db_name
  description = "Database this link is scoped to"
}

# Assembled here so the application gets a URI that already works, rather than
# five attributes it has to concatenate correctly.
#
# retryWrites=false is not optional: DocumentDB does not implement retryable
# writes and every modern driver turns them on by default, so leaving it out
# fails on the first write with a driver-level error that reads like a bug in
# the application.
#
# tlsCAFile is absent on purpose — it names a path on the client's filesystem,
# which this module cannot know. The service exports tls_ca_url for clients
# that need to load the bundle explicitly.
output "connection_string" {
  value = format(
    "mongodb://%s:%s@%s:%d/%s?tls=true&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false&authSource=admin",
    var.mongo_username,
    urlencode(random_password.user.result),
    var.docdb_host,
    var.docdb_port,
    var.db_name,
  )
  sensitive   = true
  description = "Ready-to-use mongodb:// URI for the linked application"
  depends_on  = [null_resource.mongo_user]
}

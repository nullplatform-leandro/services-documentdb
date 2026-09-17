output "endpoint" {
  value       = aws_docdb_cluster.main.endpoint
  description = "Writer endpoint of the cluster"
}

output "reader_endpoint" {
  value       = aws_docdb_cluster.main.reader_endpoint
  description = "Load-balanced endpoint across the read replicas"
}

output "port" {
  value       = aws_docdb_cluster.main.port
  description = "Cluster port (always 27017)"
}

output "cluster_identifier" {
  value       = aws_docdb_cluster.main.cluster_identifier
  description = "AWS DocumentDB cluster identifier"
}

output "master_secret_arn" {
  value       = aws_secretsmanager_secret.master.arn
  description = "ARN of the Secrets Manager secret holding master credentials"
}

output "security_group_id" {
  value       = aws_security_group.docdb.id
  description = "ID of the security group guarding the cluster"
}

# Static, but returned as an output so write_service_outputs has a single place
# to read every exported attribute from.
output "tls_ca_url" {
  value       = "https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem"
  description = "URL of the Amazon RDS global CA bundle, needed by clients to verify the cluster certificate"
}

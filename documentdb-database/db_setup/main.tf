# ---------------------------------------------------------------------------
# The database this service owns.
#
# This module creates no AWS resources at all — the cluster already exists and
# belongs to a documentdb-cluster service. All it does is reach into that
# cluster over the MongoDB wire protocol and make sure the database is there.
#
# Everything the destroy path needs lives in `triggers`, because a destroy-time
# provisioner may reference `self` and nothing else. That includes
# drop_on_delete: the decision of whether deletion takes the data with it has
# to be readable at destroy time, when var is out of reach.
# ---------------------------------------------------------------------------

resource "null_resource" "database" {
  triggers = {
    service_id        = var.service_id
    region            = var.region
    master_secret_arn = var.master_secret_arn
    docdb_host        = var.docdb_host
    docdb_port        = tostring(var.docdb_port)
    db_name           = var.db_name
    drop_on_delete    = tostring(var.drop_on_delete)
  }

  provisioner "local-exec" {
    command = "bash ${path.module}/mongo_database.sh apply"

    environment = {
      AWS_REGION = var.region
      SECRET_ARN = var.master_secret_arn
      DOCDB_HOST = var.docdb_host
      DOCDB_PORT = tostring(var.docdb_port)
      DB_NAME    = var.db_name
    }
  }

  provisioner "local-exec" {
    when    = destroy
    command = "bash ${path.module}/mongo_database.sh destroy"

    environment = {
      AWS_REGION     = self.triggers.region
      SECRET_ARN     = self.triggers.master_secret_arn
      DOCDB_HOST     = self.triggers.docdb_host
      DOCDB_PORT     = self.triggers.docdb_port
      DB_NAME        = self.triggers.db_name
      DROP_ON_DELETE = self.triggers.drop_on_delete
    }
  }
}

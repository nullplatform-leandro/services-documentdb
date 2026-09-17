# ---------------------------------------------------------------------------
# Link password
#
# keepers pins the password to the link ID, so re-applies (and the replace
# cycle an access-level change triggers) keep the credentials the app already
# holds. It only regenerates if the link itself is recreated.
# ---------------------------------------------------------------------------

resource "random_password" "user" {
  length  = 32
  special = false

  keepers = {
    link_id = var.link_id
  }
}

# ---------------------------------------------------------------------------
# MongoDB user
#
# There is no Terraform provider for DocumentDB users worth depending on, so
# provisioning runs through mongosh in a null_resource.
#
# Everything the destroy path needs lives in `triggers`, because a destroy-time
# provisioner may reference `self` and nothing else — not var, not another
# resource. The password is deliberately NOT a trigger: triggers are stored in
# plain text in the state file and echoed in plan output, and the destroy path
# has no use for it (dropUser takes no password).
#
# access_level is a trigger on purpose: changing it replaces the resource, so
# the user is dropped and recreated with the new roles. The password survives
# that cycle because of the keeper above.
# ---------------------------------------------------------------------------

resource "null_resource" "mongo_user" {
  triggers = {
    link_id           = var.link_id
    region            = var.region
    master_secret_arn = var.master_secret_arn
    docdb_host        = var.docdb_host
    docdb_port        = tostring(var.docdb_port)
    db_name           = var.db_name
    mongo_username    = var.mongo_username
    access_level      = var.access_level
  }

  provisioner "local-exec" {
    command = "bash ${path.module}/mongo_user.sh apply"

    environment = {
      AWS_REGION     = var.region
      SECRET_ARN     = var.master_secret_arn
      DOCDB_HOST     = var.docdb_host
      DOCDB_PORT     = tostring(var.docdb_port)
      DB_NAME        = var.db_name
      MONGO_USERNAME = var.mongo_username
      ACCESS_LEVEL   = var.access_level
      MONGO_PASSWORD = random_password.user.result
    }
  }

  provisioner "local-exec" {
    when    = destroy
    command = "bash ${path.module}/mongo_user.sh destroy"

    environment = {
      AWS_REGION     = self.triggers.region
      SECRET_ARN     = self.triggers.master_secret_arn
      DOCDB_HOST     = self.triggers.docdb_host
      DOCDB_PORT     = self.triggers.docdb_port
      DB_NAME        = self.triggers.db_name
      MONGO_USERNAME = self.triggers.mongo_username
      ACCESS_LEVEL   = self.triggers.access_level
    }
  }
}

# ---------------------------------------------------------------------------
# Layer 2 of 2 — agent associations (the notification channels).
#
# Apply AFTER nullplatform/. It reads the registered spec slugs out of that
# layer's state, so running it first fails on a state file that does not exist
# yet — which is the expected error, not a misconfiguration.
# ---------------------------------------------------------------------------

# Authenticates the terraform run itself. Note this is a DIFFERENT concern from
# the api_key passed to the module below: that one is written into the
# notification channel for the agent to authenticate with at runtime. They can
# be the same key, but they do not have to be — and the terraform key having
# more permissions than the agent key is the normal arrangement.
provider "nullplatform" {
  api_key = var.np_api_key
}

data "terraform_remote_state" "nullplatform" {
  backend = "local"
  config = {
    path = var.nullplatform_state_path
  }
}

module "documentdb_cluster_agent_association" {
  source = "github.com/nullplatform/tofu-modules//nullplatform/service_definition_agent_association?ref=v7.11.0"

  nrn     = var.nrn
  api_key = var.np_api_key

  service_specification_slug = data.terraform_remote_state.nullplatform.outputs.documentdb_cluster_service_specification_slug
  tags_selectors             = var.tags_selectors

  # Emits a package-exec channel instead of a git-clone one: the agent spawns a
  # worker from the package image rather than cloning this repository.
  worker_orchestrator = true
  package_slug        = "documentdb-cluster"

  # NOT optional, despite looking redundant. The module defaults the entrypoint
  # to /app/packages/<package_slug>/entrypoint, and the Dockerfile bakes
  # /app/pkg/<slug>/entrypoint/entrypoint. Those do not match. Leave it out and
  # the apply succeeds, the channel is created, and the FIRST action fails on a
  # path that is not in the image.
  entrypoint = "/app/pkg/documentdb-cluster/entrypoint/entrypoint"

  description = "AWS DocumentDB cluster provisioning"
}

module "documentdb_database_agent_association" {
  source = "github.com/nullplatform/tofu-modules//nullplatform/service_definition_agent_association?ref=v7.11.0"

  nrn     = var.nrn
  api_key = var.np_api_key

  service_specification_slug = data.terraform_remote_state.nullplatform.outputs.documentdb_database_service_specification_slug
  tags_selectors             = var.tags_selectors

  worker_orchestrator = true
  package_slug        = "documentdb-database"
  entrypoint          = "/app/pkg/documentdb-database/entrypoint/entrypoint"

  description = "Database provisioning inside an existing DocumentDB cluster"
}

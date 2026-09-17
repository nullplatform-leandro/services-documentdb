# ---------------------------------------------------------------------------
# Layer 1 of 2 — service specifications + packages.
#
# This directory does NOT belong in the service repository: it belongs in the
# infrastructure repo of whoever is installing the service. It lives here as a
# ready-to-copy example, which is also why it carries no backend block — yours
# decides that.
#
# Apply this first. nullplatform-bindings/ reads the spec slugs out of this
# state through terraform_remote_state, so the order is not a suggestion.
#
# Two propagation paths, and the difference is the single easiest thing to get
# wrong here:
#   • specs/     are re-read from the repository on EVERY apply. Change a
#     schema, a uiSchema, a selector or a link and an apply is enough.
#   • everything else (scripts/, workflows/, deployment/, permissions/,
#     values.yaml) is baked into the image. Change any of those and you need
#     rebuild -> new digest -> bumped package.version -> apply. Editing a
#     script and only applying does nothing at all: the worker keeps running
#     what is inside the image.
# ---------------------------------------------------------------------------

# The service_definition module takes NO api_key: it authenticates through the
# provider. This is not the same key as the one nullplatform-bindings/ passes to
# the agent association — that one is embedded in the notification channel for
# the AGENT to use at runtime. Same kind of credential, two different consumers,
# and they may legitimately be different keys with different permissions.
provider "nullplatform" {
  api_key = var.np_api_key
}

# Modules are pinned to v7.11.0 below. Terraform cannot interpolate a module
# source, so the ref is repeated literally in each block rather than held in a
# variable — bump both together.
module "service_definition_documentdb_cluster" {
  source = "github.com/nullplatform/tofu-modules//nullplatform/service_definition?ref=v7.11.0"

  nrn = var.nrn

  service_name = "AWS DocumentDB Cluster"
  service_path = "documentdb-cluster"

  git_provider      = "github"
  repository_org    = var.service_repository_org
  repository_name   = var.service_repository_name
  repository_branch = var.service_repository_ref
  repository_token  = var.service_repository_token

  # Explicit even though ["connect"] is the default: the failure mode when this
  # is wrong is an apply error about a spec file that was never written, which
  # reads like a missing file rather than a wrong list.
  available_links = ["connect"]

  package = {
    version = var.package_version
    artifacts = [{
      name = "worker"
      # Explicit on purpose. The default is "git_repository", and an oci_image
      # entry that omits `repository` silently falls back to the containers
      # scope image instead of failing.
      type = "oci_image"
      meta = {
        registry   = var.image_registry
        repository = var.cluster_image_repository
        digest     = var.cluster_image_digest
      }
    }]
  }
}

module "service_definition_documentdb_database" {
  source = "github.com/nullplatform/tofu-modules//nullplatform/service_definition?ref=v7.11.0"

  nrn = var.nrn

  service_name = "AWS DocumentDB Database"
  service_path = "documentdb-database"

  git_provider      = "github"
  repository_org    = var.service_repository_org
  repository_name   = var.service_repository_name
  repository_branch = var.service_repository_ref
  repository_token  = var.service_repository_token

  available_links = ["connect"]

  package = {
    version = var.package_version
    artifacts = [{
      name = "worker"
      type = "oci_image"
      meta = {
        registry   = var.image_registry
        repository = var.database_image_repository
        digest     = var.database_image_digest
      }
    }]
  }
}

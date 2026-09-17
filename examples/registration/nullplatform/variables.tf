variable "nrn" {
  type        = string
  description = "Account NRN, e.g. organization=1698562351:account=1632518251"
}

variable "np_api_key" {
  type        = string
  sensitive   = true
  description = "nullplatform API key. Deliberately has no default and is NOT in common.tfvars — pass it through TF_VAR_np_api_key so it never lands in a file."
}

variable "service_repository_org" {
  type        = string
  default     = "nullplatform-leandro"
  description = "GitHub owner of THIS repository. The module fetches the spec files over HTTPS on every apply, so this must be reachable."
}

variable "service_repository_name" {
  type        = string
  default     = "services-documentdb"
  description = "Name of THIS repository"
}

variable "service_repository_ref" {
  type        = string
  description = "Tag of this repository to read the specs from. Must be a TAG — the module rejects a branch name. Tag before building so the image and the specs describe the same commit."
}

variable "service_repository_token" {
  type        = string
  sensitive   = true
  default     = null
  description = "Fine-grained GitHub token with Contents: Read-only. REQUIRED while this repository is private: the module fetches the specs over HTTPS on every apply, so a private repo without a token fails at plan time, not at runtime. Leave null once the repository is public."
}

variable "image_registry" {
  type        = string
  default     = "public.ecr.aws"
  description = "Registry host holding the worker images"
}

variable "cluster_image_repository" {
  type        = string
  default     = "nullplatform/services/documentdb-cluster"
  description = "Repository path of the documentdb-cluster worker image"
}

variable "database_image_repository" {
  type        = string
  default     = "nullplatform/services/documentdb-database"
  description = "Repository path of the documentdb-database worker image"
}

variable "cluster_image_digest" {
  type        = string
  description = "Digest of the documentdb-cluster image, as sha256:<64 hex>. Changes on every release; bumping it without bumping package_version publishes nothing."
}

variable "database_image_digest" {
  type        = string
  description = "Digest of the documentdb-database image, as sha256:<64 hex>"
}

variable "package_version" {
  type        = string
  description = "Semver of the package revision this configuration publishes. A new digest with an unchanged version does not reach running services — existing instances stay bound for life to the revision they were born with."
}

terraform {
  required_providers {
    nullplatform = {
      source = "nullplatform/nullplatform"
      # Package artifact lookup by identity needs >= 0.0.104. Below that the
      # platform merges the previous default revision's components back in, so
      # an artifact removed from the BOM silently survives into later revisions.
      version = ">= 0.0.104"
    }
  }
}

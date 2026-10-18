terraform {
  # use_lockfile (S3 native state locking) is GA from 1.11.0.
  required_version = ">= 1.11.0, < 2.0.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.28"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.13"
    }
  }

  # State lives in the R2 bucket aloong-planet-tfstate, which is created by hand
  # outside this configuration. Credentials come from AWS_ACCESS_KEY_ID and
  # AWS_SECRET_ACCESS_KEY, and the endpoint from AWS_ENDPOINT_URL_S3, so the
  # account ID never appears in the repository. Every stack has its own key;
  # this one predates the split into stacks and was kept so the state did not
  # have to move.
  backend "s3" {
    bucket       = "aloong-planet-tfstate"
    key          = "infra/terraform.tfstate"
    region       = "auto"
    use_lockfile = true

    use_path_style              = true
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
  }
}

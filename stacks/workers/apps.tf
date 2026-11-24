# The apps stack's outputs: the Workers deploy token it mints, and each app's
# download count settings (stacks/apps/outputs.tf). Read from its state with
# the same backend settings and credentials as this stack's own state, so a
# plan here sees what apps' last apply wrote: apps applies first when both
# change.
data "terraform_remote_state" "apps" {
  backend = "s3"

  config = {
    bucket = "aloong-planet-tfstate"
    key    = "infra/terraform.tfstate"
    region = "auto"

    use_path_style              = true
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
  }
}

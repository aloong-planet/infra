variable "account_id" {
  description = "Cloudflare account that owns the bucket."
  type        = string
  sensitive   = true
}

variable "zone_id" {
  description = "Zone that serves download_host."
  type        = string
}

variable "writer_permission_group_id" {
  description = "ID of the Workers R2 Storage Bucket Item Write permission group."
  type        = string
}

variable "repository" {
  description = "Repository, under the GitHub provider's owner, that receives the R2_* Actions secrets."
  type        = string
}

variable "bucket" {
  description = "R2 bucket for the app's releases. The writer token is named after it."
  type        = string
}

variable "download_host" {
  description = "Public hostname of the bucket, in the zone_id zone."
  type        = string
}

variable "allowed_origins" {
  description = "Origins allowed to GET from the bucket cross-origin, such as the app's landing page."
  type        = list(string)

  validation {
    condition     = length(var.allowed_origins) > 0 && alltrue([for origin in var.allowed_origins : startswith(origin, "https://")])
    error_message = "allowed_origins must list at least one https:// origin."
  }
}

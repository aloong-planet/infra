variable "account_id" {
  description = "Cloudflare account that owns the Pages project."
  type        = string
  sensitive   = true
}

variable "zone_id" {
  description = "Zone that serves domain."
  type        = string
}

variable "project_name" {
  description = "Pages project name. Cloudflare derives the project's pages.dev host from it."
  type        = string
}

variable "repository_owner" {
  description = "GitHub organization or user that owns repository."
  type        = string
}

variable "repository" {
  description = "Repository the project builds from. The Cloudflare Workers & Pages GitHub App must have access to it."
  type        = string
}

variable "production_branch" {
  description = "Branch whose pushes deploy to domain. Pushes to other branches get preview deployments."
  type        = string
}

variable "root_dir" {
  description = "Directory of the repository the build runs in."
  type        = string
}

variable "build_command" {
  description = "Command that builds the site, run in root_dir."
  type        = string
}

variable "output_dir" {
  description = "Directory the build writes the site to, relative to root_dir."
  type        = string
}

variable "build_env" {
  description = "Plain-text environment variables for production and preview builds, such as NODE_VERSION."
  type        = map(string)
  default     = {}
}

variable "watch_paths" {
  description = "Paths in the repository whose changes start a build. `*` matches any characters, `/` included."
  type        = list(string)
}

variable "domain" {
  description = "Custom domain of the landing page, in the zone_id zone."
  type        = string
}

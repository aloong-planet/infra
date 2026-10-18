# agentshed's resources were declared in the root module before the
# release-mirror module existed. These blocks move them in the state instead of
# replacing them: replacing would delete and recreate the bucket, rotate the
# writer token and with it agentshed's secrets, and reissue the download host's
# certificate. The CORS rules and the custom domain cannot be imported back.
#
# Once applied they change nothing. Keep them: a state snapshot from history/
# taken before the move still has the old addresses.

moved {
  from = cloudflare_r2_bucket.agentshed_releases
  to   = module.release_mirror["agentshed"].cloudflare_r2_bucket.this
}

moved {
  from = cloudflare_r2_bucket_cors.agentshed_releases
  to   = module.release_mirror["agentshed"].cloudflare_r2_bucket_cors.this
}

moved {
  from = cloudflare_r2_custom_domain.agentshed_download
  to   = module.release_mirror["agentshed"].cloudflare_r2_custom_domain.this
}

moved {
  from = cloudflare_account_token.agentshed_releases_writer
  to   = module.release_mirror["agentshed"].cloudflare_account_token.writer
}

moved {
  from = github_actions_secret.agentshed_r2
  to   = module.release_mirror["agentshed"].github_actions_secret.r2
}

# Transfer's landing page was made in the Cloudflare dashboard, before the
# landing-page module existed. These blocks bring its three resources (the
# Pages project, its custom domain and the CNAME that points the domain at it)
# into the state at the next apply. The transfer-org entry in landing-pages.tf
# held the values the live project had, so the import changes nothing the site
# serves with (the entry's Git builds were turned off afterwards; see its
# comment). The plan still shows three updates next to the imports: the project
# and the domain change no value (the account ID comes from a sensitive
# variable, an imported resource has no sensitivity marks, and Terraform plans
# that as an update), and the DNS record gets the comment the module gives
# every landing page's record, which the dashboard left empty.
#
# Once the resources are in the state, Terraform skips the blocks, as it has
# since the apply of 2026-11-24 that imported them: a plan no longer shows the
# three updates above. Delete this file together with the transfer-org entry if
# Transfer's page is ever removed: an import block whose target is gone fails
# the plan.
#
# The DNS record is looked up by its name instead of its ID, so no ID is
# written here. Its block runs once per record found, so a record deleted in
# the dashboard later shows up as an addition in the plan, as it does for the
# other landing pages, and does not fail every plan of this stack on a missing
# index.

data "cloudflare_dns_records" "transfer" {
  zone_id = data.cloudflare_zone.aloongplanet.id
  type    = "CNAME"
  name = {
    exact = local.landing_pages["transfer-org"].domain
  }
}

import {
  to = module.landing_page["transfer-org"].cloudflare_pages_project.this
  id = "${var.cloudflare_account_id}/transfer-org"
}

import {
  to = module.landing_page["transfer-org"].cloudflare_pages_domain.this
  id = "${var.cloudflare_account_id}/transfer-org/${local.landing_pages["transfer-org"].domain}"
}

import {
  for_each = length(data.cloudflare_dns_records.transfer.result) > 0 ? { transfer = data.cloudflare_dns_records.transfer.result[0].id } : {}
  to       = module.landing_page["transfer-org"].cloudflare_dns_record.this
  id       = "${data.cloudflare_zone.aloongplanet.id}/${each.value}"
}

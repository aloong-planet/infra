# Transfer's landing page was made in the Cloudflare dashboard, before the
# landing-page module existed. These blocks bring its three resources (the
# Pages project, its custom domain and the CNAME that points the domain at it)
# into the state at the next apply, without changing them: the transfer-org
# entry in landing-pages.tf holds the values the live project had, so the plan
# reads "3 to import" and nothing else.
#
# Once applied they change nothing. Delete this file together with the
# transfer-org entry if Transfer's page is ever removed: an import block whose
# target is gone fails the plan.
#
# The DNS record is looked up by its name instead of its ID, so no ID is
# written here.

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
  to = module.landing_page["transfer-org"].cloudflare_dns_record.this
  id = "${data.cloudflare_zone.aloongplanet.id}/${data.cloudflare_dns_records.transfer.result[0].id}"
}

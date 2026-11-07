# Zone settings

## Overview

Visitors returning to a site on aloongplanet.com need the stylesheets and scripts of its latest deploy, or new pages show with an old stylesheet. Browsers keep each file for as long as the site that serves it says, and that rule changes only through a change the owner reviews and approves.

## Capabilities

- A returning visitor to the personal homepage gets the stylesheets and scripts of the latest deploy on their next page load: the browser checks each file again on every visit.
- Every site on aloongplanet.com, Transfer, agentshed and the download hosts included, has its files cached in the browser for as long as that site says.
- Transfer's and agentshed's pages check their files again on every visit, and an unchanged file is answered without being downloaded again.
- A download that asks to be kept for a year is still kept for a year.
- The rule for the whole of aloongplanet.com changes only through a change the owner reviews and approves. A change made by hand in the Cloudflare dashboard is put back the next time the owner runs the check.

## Boundaries and non-goals

- A visitor who loaded a page in the 4 hours before the rule changed can keep that older copy until it expires, at most 4 hours, or until they reload the page.
- A hand-made change in the dashboard holds until the owner next runs the check; nothing runs it on a schedule.
- Only what browsers are told changes; Cloudflare's own caching of these files is unchanged.
- A longer browser cache for Transfer's and agentshed's files is up to those sites themselves.
- The owner can change only this one setting this way. Every other setting of aloongplanet.com, and its DNS records outside the apps' landing pages, are managed elsewhere.

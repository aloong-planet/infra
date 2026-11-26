# Voice assistant Access application

This stack creates one self-hosted Access application covering every path of
`voice.aloongplanet.com`, including both WebSocket endpoints. Configure the
following before approving the first plan.

1. In Zero Trust, select or create a reusable **Allow** policy that includes
   exactly the owner's email address. Verify that it has no other Include rule.
   Find the account's **One-time PIN** login method and enable it if needed.
   Keep the email in the Access policy. Terraform references the policy by ID.
2. Use the existing GitHub `production` environment. Set `VOICE_OWNER_POLICY_ID`
   and `VOICE_OTP_IDP_ID` as environment variables. Add `CLOUDFLARE_ACCESS_API_TOKEN`
   as an environment secret for a dedicated token with **Access: Apps and Policies
   Write** on this Cloudflare account. The workflow uses it for both Plan and Apply
   and reuses the existing account ID, R2 credentials and deployment approvals.
3. Check for an existing application on the hostname before the first apply.
   If one exists, import it into this stack and review its current policies
   before applying. For a new app the plan should add only
   `cloudflare_zero_trust_access_application.voice`. Approve the plan and
   apply through the stack workflow. Get the Application Audience (AUD) Tag
   from the created app's details and configure the Mac origin.
4. Publish the hostname through the Mac's tunnel after Access is in place.
   Verify an unsigned request reaches the Access login screen. After signing
   in, open the memory list to verify the WebSocket without starting a call.

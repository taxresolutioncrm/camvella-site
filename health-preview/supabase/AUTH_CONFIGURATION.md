# Supabase Auth Configuration Gate

Apply these settings only in the dedicated project.

## Redirects
- Production app origin only
- Explicit password-recovery callback
- Explicit magic-link callback
- No wildcard production redirects

## Email
- Require verified email before normal workspace access
- Use the agency/product outbound mail provider before production
- Test signup, invite, recovery, and magic-link delivery

## Password protection
- Enable leaked-password protection
- Configure minimum password length appropriate for the deployment
- Do not use browser-side password policy as the security boundary

## MFA
- Enable TOTP enrollment
- Require MFA for agency_admin accounts before production
- Strongly require MFA for manager, compliance, and revenue roles
- Test challenge/verify/recovery behavior before launch

## Session behavior
- Verify session expiration and refresh behavior
- Verify access revocation after membership disable/role change
- Refresh workspace authorization after membership changes
- Do not treat deleting an Auth user as the only revocation mechanism

## Authorization
- Membership rows / trusted server state are authoritative
- Never authorize from user_metadata
- Browser UI permissions are convenience only; RLS/server checks remain authoritative

## Abuse protection
- Enable CAPTCHA/bot protection for public signup where used
- Public lead/booking Edge Functions stay disabled until PUBLIC_ENDPOINT_SALT and rate limits are configured

## Target verification
- signup
- sign in
- sign out
- password reset
- magic link
- TOTP enroll/challenge/verify
- disabled membership denial
- changed-role session refresh
- invitation acceptance
- portal invitation acceptance

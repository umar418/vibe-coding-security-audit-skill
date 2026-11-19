# Security audit report: InvoiceFlow (example)

> **This is an illustrative example.** "InvoiceFlow" is a made-up invoicing app. The findings show the format and level of detail the skill produces. They don't describe a real codebase.

**Date:** 2026-11-20
**Scope:** Whole repository (`app/`, `lib/`, `supabase/migrations/`). Code review only, no live testing.
**Stack detected:** Next.js 15 (App Router) + Supabase (Postgres, Auth, Storage) + Vercel

## Summary

The app has two critical issues that should be fixed before any real customer data goes in. Any signed-in user can read other customers' invoices, and the `invoices` table has Row Level Security turned off while the public anon key is in use. Together these expose every customer's billing data. The other findings are standard hardening gaps that are common in AI-built apps: missing rate limits, missing security headers and a permissive CORS setting.

| Severity | Count |
|---|---|
| 🔴 Critical | 2 |
| 🟠 High | 2 |
| 🟡 Medium | 3 |
| 🔵 Low | 1 |

## Findings

### 🔴 Any logged-in user can read any other user's invoices

- **Category:** 5. Broken Object Level Authorization
- **Location:** `app/api/invoices/[id]/route.ts:14`
- **Issue:** The handler loads the invoice with `where: { id: params.id }` and never checks who owns it. A signed-in user who changes the ID in `GET /api/invoices/<id>` gets another customer's invoice: name, address, line items and amount.
- **Impact:** Every customer's billing data can be read by any account. Invoice IDs are sequential integers, so enumerating all of them is trivial.
- **Fix:** Scope the query to the caller and return 404 (not 403) when nothing matches, so the response doesn't confirm the invoice exists:
  ```ts
  const invoice = await db.invoice.findFirst({
    where: { id: params.id, userId: session.user.id },
  });
  if (!invoice) return new Response("Not found", { status: 404 });
  ```
- **Status:** Fixed in this session

### 🔴 Row Level Security disabled on `invoices` and `customers`

- **Category:** 10.1 Row Level Security
- **Location:** `supabase/migrations/20261102_init.sql` (tables created without `ENABLE ROW LEVEL SECURITY`); the client uses `NEXT_PUBLIC_SUPABASE_ANON_KEY`
- **Issue:** The browser talks to Supabase directly with the anon key, and neither table has RLS turned on. Anyone can call the Supabase REST API with the public key and run `select * from invoices`, completely bypassing the app's own API.
- **Impact:** Full read and write access to all invoices and customers for anyone who opens dev tools.
- **Fix:** Added a migration that enables RLS and adds per-operation policies scoped to `auth.uid() = user_id`. Verified by querying as the `anon` and `authenticated` roles, not the service role.
- **Status:** Fixed in this session

### 🟠 Stored XSS in invoice notes

- **Category:** 2. Cross-site scripting
- **Location:** `app/invoices/[id]/InvoiceView.tsx:52`
- **Issue:** Customer-supplied `notes` are rendered with `dangerouslySetInnerHTML` so line breaks display. A note containing `<img src=x onerror=...>` runs script in the browser of whoever views the invoice, including the account owner.
- **Impact:** Session theft or actions taken as the victim.
- **Fix:** Render as plain text with CSS `white-space: pre-wrap` instead of injecting HTML.
- **Status:** Fixed in this session

### 🟠 Stripe webhook doesn't verify signatures

- **Category:** 14. Webhooks
- **Location:** `app/api/webhooks/stripe/route.ts:8`
- **Issue:** The handler parses the JSON body and marks invoices paid on `payment_intent.succeeded` without calling `stripe.webhooks.constructEvent`.
- **Impact:** Anyone can POST a fake event and mark any invoice as paid.
- **Fix:** Verify with `stripe.webhooks.constructEvent(rawBody, signature, STRIPE_WEBHOOK_SECRET)` using the raw request body, and store processed event IDs to reject replays.
- **Status:** Fixed in this session. `STRIPE_WEBHOOK_SECRET` must be added in Vercel's environment variables before deploying.

### 🟡 No rate limiting on login or password reset

- **Category:** 6. Rate limiting & abuse
- **Location:** `app/(auth)/login/actions.ts`, `app/(auth)/reset/actions.ts`
- **Issue:** Unlimited attempts are allowed, so the login form can be used for credential stuffing and the reset form can be used to flood a user's inbox.
- **Impact:** Account takeover through reused passwords, plus email-sending costs.
- **Fix:** Recommended per-IP and per-email limits (for example Upstash Ratelimit or Vercel Firewall rules). Not applied, because it needs a provider choice and new infrastructure.
- **Status:** Flagged for you to fix

### 🟡 Missing security headers

- **Category:** 13. Security headers & HTTPS
- **Location:** `next.config.ts`
- **Issue:** No `Content-Security-Policy`, `Strict-Transport-Security`, `X-Content-Type-Options` or frame protection.
- **Fix:** Added a `headers()` block with HSTS, `nosniff`, `frame-ancestors 'none'` and Referrer-Policy. CSP is added in report-only mode first so it doesn't break third-party scripts.
- **Status:** Fixed in this session

### 🟡 CORS allows any origin with credentials

- **Category:** 12. CORS
- **Location:** `middleware.ts:21`
- **Issue:** `Access-Control-Allow-Origin` echoes the request's `Origin` header back, together with `Access-Control-Allow-Credentials: true`.
- **Fix:** Replaced with an explicit allowlist (the production domain and `localhost:3000` in development).
- **Status:** Fixed in this session

### 🔵 Production source maps are publicly served

- **Category:** 15.1 Source maps
- **Location:** `next.config.ts` (`productionBrowserSourceMaps: true`)
- **Fix:** Set it to `false`. Upload maps privately to your error tracker if you need readable stack traces.
- **Status:** Fixed in this session

## Not checked / out of scope

- No live or dynamic testing: no requests were sent to a running instance.
- Vercel project settings, DNS and Supabase dashboard settings beyond what's in migrations weren't reviewed.
- `npm audit` reported 0 high or critical advisories. Individual CVEs weren't investigated further.

## Recommended next steps

1. **Before launch:** deploy the RLS migration and the authorization fix, and add `STRIPE_WEBHOOK_SECRET` in Vercel.
2. **Before launch:** add rate limiting to login and password reset.
3. **Soon:** move CSP from report-only to enforcing once the reports come back clean.
4. **Soon:** switch invoice IDs to UUIDs as an extra layer on top of the ownership checks.

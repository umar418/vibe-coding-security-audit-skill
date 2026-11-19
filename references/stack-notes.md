# Stack-specific notes

Quick pointers for where each checklist item tends to live in the stacks "vibe coded" apps most often use. Read the relevant section(s) once you've identified the stack; skip the rest.

## Next.js / Vercel

- **Secrets:** only `NEXT_PUBLIC_*` env vars reach the browser bundle — grep for any secret-looking value under that prefix. Everything else stays server-only automatically, but Server Actions and API routes (`app/api/**`, `pages/api/**`) still need their own authz checks; a Server Action is a public HTTP endpoint with a generated name, not a private function call.
- **Source maps:** check `next.config.js` for `productionBrowserSourceMaps` — should be `false` (default) unless you upload maps privately to an error tracker.
- **Headers:** set security headers via `headers()` in `next.config.js` or `middleware.ts`, not left to defaults.
- **Middleware authz:** if `middleware.ts` is the only authz gate, confirm it actually covers every protected path pattern — a new route added later can silently fall outside the matcher.
- **Image/API proxy routes:** a `/api/proxy?url=` or image-optimizer-style route is a classic SSRF vector — check it against an allowlist.

## Supabase

- **RLS is the big one.** Any table reachable with the `anon` or `authenticated` key needs RLS enabled with real policies — check this before anything else in a Supabase app. Open Table Editor → each table → confirm RLS is "Enabled" with policies, or query `pg_tables`/`pg_policies` directly.
- **Service role key** (`SUPABASE_SERVICE_ROLE_KEY`) bypasses RLS entirely — it must never reach client code or a public env var prefix. It belongs only in server-side code (Edge Functions, API routes, server actions).
- **Storage buckets:** confirm bucket policies match intent — a bucket created "public" during prototyping often stays public after the app goes live. Check Storage policies the same way as table RLS.
- **Realtime/Postgres changes:** subscriptions respect RLS, but double-check broadcast/presence channels aren't leaking data to users who shouldn't see it.
- **Auth:** Supabase Auth handles password hashing/JWT signing for you — don't re-implement; just make sure custom claims/role checks in RLS policies and server code agree with each other.

## Firebase

- **Firestore/Realtime DB security rules** are the RLS equivalent — default rules in test mode (`allow read, write: if true;`) are commonly left in place after prototyping. Check `firestore.rules` / `database.rules.json` for anything permissive, and confirm rules were actually deployed (`firebase deploy --only firestore:rules`), not just written locally.
- **Client SDK config (`apiKey`, project ID, etc.) is not a secret** by Firebase's design — don't waste time flagging it as leaked; the real boundary is the security rules, not key secrecy.
- **Cloud Functions** that are HTTP-triggered need their own authz checks same as any API route — being "a Firebase Function" doesn't imply access control.
- **Storage rules** mirror Firestore rules — check separately.

## Node/Express (or similar custom backend)

- **Everything is manual here** — there's no framework default doing CSRF/headers/rate limiting for you. Check explicitly for: `helmet()` (headers), CORS config, a rate-limit middleware, CSRF middleware if using cookie sessions, and that every route group has its auth middleware actually attached (easy to forget on one router).
- **ORM raw escape hatches:** Sequelize `.literal()`/`.query(raw)`, Knex `.raw()`, TypeORM `.query()` — all bypass the ORM's own injection protection.
- **Session store:** default in-memory session store (`express-session` default `MemoryStore`) isn't meant for production — not a security bug per se, but worth flagging for session loss/scale, and confirm whatever store is used still sets the cookie flags correctly.

## WordPress / PHP

- **Default creds / exposed admin:** `/wp-admin` reachable with default or weak creds is the #1 compromise vector — confirm a strong unique password and consider rate-limiting/2FA plugins.
- **Plugin/theme vulnerabilities:** outdated plugins are the dependency-scanning equivalent here — check installed plugin versions against known CVEs, remove unused plugins/themes entirely (inactive code is still a live attack surface if it's on disk and reachable).
- **File upload:** the media library and any custom upload form need the same content-type/size/location checks as §4 of the main checklist; `wp-content/uploads` executing PHP is a classic RCE path — confirm the web server config disallows executing PHP from the uploads directory.
- **`wp-config.php` secrets:** DB credentials and auth salts — confirm this file isn't web-readable and isn't committed to a public repo.

## Generic SaaS boilerplate / "AI app in a weekend" patterns

These show up across stacks because they're what a fast first pass tends to skip:
- Auth was wired up via a tutorial/template and the authz (who can access *which* row) was never layered on top — the checklist's §5 and §9 are the ones most often missing entirely, not just weakened.
- CORS set to `*` "to make it work" during development and never tightened.
- A single shared Postgres/Supabase instance with RLS still off because the whole app was built against the `anon` key for speed.
- Rate limiting and MFA are usually just absent, not misconfigured — they were never added, so look for their absence rather than a broken version of them.

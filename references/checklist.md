# The full checklist

Organized by category. For every item: **why it matters**, **how to check it in this codebase**, and **how to fix it**. Severity tags: 🔴 Critical, 🟠 High, 🟡 Medium, 🔵 Low/hygiene.

Grep patterns below are starting points, not proof of safety or danger — a hit needs a human read of the surrounding code, and a miss doesn't clear the item (string-built queries, custom auth, etc. can dodge any single pattern).

---

## 1. Injection

### 1.1 SQL injection 🔴
- **Why:** string-concatenated or template-literal SQL lets an attacker change the query's meaning (`' OR 1=1`, `; DROP TABLE`).
- **Check:** grep for raw query calls with interpolation: `query(\`.*\${`, `.raw(`, string `+` next to `SELECT|INSERT|UPDATE|DELETE`, f-strings into `cursor.execute`. ORM use doesn't guarantee safety — `sequelize.query(rawString)`, `prisma.$queryRawUnsafe`, `knex.raw(unsanitized)` are still raw SQL.
- **Fix:** parameterized queries / prepared statements everywhere, or stick to the ORM's query builder (not its raw escape hatches) for anything touching user input.

### 1.2 NoSQL / query injection 🟠
- **Why:** MongoDB and similar accept operators (`$where`, `$gt`, `$regex`) inside JSON bodies — an unsanitized `req.body` can smuggle them in.
- **Check:** does any `find()`/`findOne()`/`update()` pass `req.query`/`req.body` straight through without a schema?
- **Fix:** validate/whitelist the shape of input (zod/joi/pydantic) before it reaches the query layer; strip or reject keys starting with `$`.

### 1.3 Command injection 🔴
- **Why:** shelling out with user-controlled strings lets an attacker run arbitrary commands.
- **Check:** `exec(`, `child_process.exec`, `os.system`, `subprocess.*(shell=True)`, backticks in shell scripts, where any argument traces back to user input.
- **Fix:** avoid shelling out; if unavoidable, use the array/argv form (`execFile`, `subprocess.run([...], shell=False)`) and an allowlist of acceptable values, never string interpolation.

### 1.4 Server-Side Template Injection 🟠
- **Why:** rendering user input as a template (not just a variable) lets an attacker execute template-language code.
- **Check:** user input passed to `render_template_string`, `eval`-like templating, or any `{{ user_input }}` construction where the input itself — not just the data — comes from the user.
- **Fix:** never pass user-controlled strings as the template itself; only as data into a fixed template.

---

## 2. Cross-site scripting (XSS) 🔴

- **Why:** unescaped user content rendered as HTML/JS runs in another user's browser with their session — the classic account-takeover vector.
- **Check:**
  - React/Vue: `dangerouslySetInnerHTML`, `v-html`, `innerHTML =` with anything not hard-coded.
  - Server-rendered templates: autoescaping disabled (`|safe` in Jinja2, `<%- %>` vs `<%= %>` in EJS, `{{{ }}}` in Handlebars).
  - Reflected XSS: query params or path segments echoed into the page without encoding.
  - Stored XSS: user-submitted text (bios, comments, product descriptions) rendered later without sanitization.
- **Fix:** let the framework's default escaping do its job; if you must render user HTML, run it through a sanitizer allowlist (DOMPurify, bleach) server- and client-side, not a blocklist. Add a Content-Security-Policy as defense in depth (see §9).

---

## 3. CSRF — Cross-Site Request Forgery 🟠

- **Why:** a logged-in user's browser can be tricked into firing a state-changing request to your app; cookies ride along automatically.
- **Check:** does every state-changing route (POST/PUT/PATCH/DELETE) that relies on cookie-based sessions check a CSRF token or rely on `SameSite=Lax/Strict` cookies? Pure Bearer-token APIs (token in header, not cookie) are naturally immune — confirm which model you're in before flagging this.
- **Fix:** CSRF middleware (`csurf`, framework-native CSRF protection) for cookie-session apps, or move to Bearer tokens in an `Authorization` header (not a cookie) for APIs. Set cookies `SameSite=Lax` or `Strict` either way.

---

## 4. File upload handling 🟠

- **Why:** uploads are a path to remote code execution (uploading a script into a web-served directory), stored XSS (an "image" that's actually HTML/SVG with script), storage abuse, or path traversal.
- **Check:**
  - Is the file type validated by **content** (magic bytes / library sniff), not just the client-supplied extension or `Content-Type` header?
  - Is there a size limit?
  - Are uploaded files stored outside the web root, or in object storage (S3/GCS/Supabase Storage) with private-by-default ACLs and served via signed URLs?
  - Is the filename sanitized/randomized (no `../../` path traversal, no executing the original name)?
  - Are SVG uploads sanitized (they can carry `<script>`) or disallowed?
  - Is there malware/antivirus scanning for anything re-shared to other users?
- **Fix:** allowlist MIME types by content inspection, cap size, randomize stored filenames, store in a non-executable location or private bucket, generate short-lived signed URLs for access, sanitize SVGs or convert to raster.

---

## 5. Broken Object Level Authorization (BOLA/IDOR) 🔴

- **Why:** the single most common real-world API bug — an endpoint fetches/updates a resource by ID without checking the caller actually owns or is allowed to see it (`GET /api/orders/123` returns anyone's order 123).
- **Check:** for every route that takes an ID (path param, body field, query param), trace whether the handler filters by the authenticated user/tenant, or just trusts the ID. This includes "hidden" IDs in GraphQL resolvers and batch/bulk endpoints.
- **Fix:** always scope the database lookup by the authenticated principal (`WHERE user_id = :currentUser AND id = :id`, or equivalent ORM clause), never just `WHERE id = :id`. Prefer non-guessable IDs (UUIDv4, not sequential integers) as a secondary hardening, not a substitute for the check.

### 5.1 Broken Function Level Authorization 🔴
- **Why:** sibling bug — an admin-only action is reachable by a regular user because the route only checks "is logged in," not "is allowed to do *this*."
- **Check:** every privileged route/mutation (delete user, change role, refund, export data) — does it re-check role/permission server-side, or did the check only exist in the UI (a hidden button)?
- **Fix:** centralize authorization (middleware/guard/policy layer) and apply it per-route, not per-button.

---

## 6. Rate limiting & abuse protection 🟡

- **Why:** without limits, login forms invite credential stuffing, password-reset/OTP endpoints invite brute force, and any paid API behind your app (including an LLM provider) invites a cost-based DoS.
- **Check:** is there rate limiting (per-IP and per-account) on: login, signup, password reset, OTP/MFA verification, search, and any endpoint that calls a metered third-party API? Is there account lockout or exponential backoff after repeated auth failures?
- **Fix:** rate-limit middleware (`express-rate-limit`, API gateway/WAF rules, Cloudflare, Vercel Firewall) keyed by IP + account; CAPTCHA on auth-sensitive forms after N failures; exponential lockout, not permanent lockout (to avoid a DoS-by-lockout against legit users).

---

## 7. Secrets & key management 🔴

### 7.1 Secure JWT secrets
- **Why:** a weak, default, or guessable JWT signing secret lets an attacker forge tokens and impersonate anyone.
- **Check:** is the secret long and random (32+ bytes), loaded from env/secret manager, not hard-coded, not a project name or "secret123"? Is the algorithm pinned server-side (reject `alg: none` and algorithm-confusion between HS256/RS256)? Are tokens short-lived with a refresh flow, not permanent?
- **Fix:** generate with a CSPRNG, store in a secret manager, pin the expected algorithm when verifying, short expiry + refresh tokens, rotate on suspected compromise.

### 7.2 Keep API secrets server-side
- **Why:** anything shipped to the browser (env vars without a server-only prefix, hard-coded keys in client JS) is public — view-source public.
- **Check:** grep the client bundle / any `NEXT_PUBLIC_`, `VITE_`, `REACT_APP_`-prefixed env vars and confirm only genuinely public values (not secret keys) use that prefix. Search client-side code for API keys matching provider patterns (`sk-`, `AKIA`, etc.).
- **Fix:** secret keys only in server-side env vars / secret manager, never in a client bundle; proxy third-party calls (including LLM calls) through your own backend.

### 7.3 No secrets in source control
- **Why:** a secret committed once is compromised forever (git history persists even after deletion).
- **Check:** `.env*` in `.gitignore`? Run a secret scanner (gitleaks/truffleHog) over the full git history, not just HEAD.
- **Fix:** if something leaked, rotate it immediately — removing it from history is not enough since it may already be scraped/cached. Add a pre-commit secret-scanning hook and a CI step.

### 7.4 Password hashing 🔴
- **Why:** fast general-purpose hashes (MD5, SHA-1, even unsalted SHA-256) are crackable at billions of guesses/second on commodity GPUs.
- **Check:** what's used to store passwords — bcrypt/argon2/scrypt (good), vs MD5/SHA1/SHA256/plain text (bad)? Is there a unique salt (these algorithms handle it internally — just confirm you're using the library's own API, not rolling your own).
- **Fix:** bcrypt (cost ≥ 10-12) or argon2id with tuned parameters. Never store or log plaintext passwords, even transiently.

### 7.5 Multi-factor authentication 🟡
- **Why:** a leaked/guessed password shouldn't be the only thing standing between an attacker and the account, especially for admin/privileged accounts.
- **Check:** is MFA (TOTP, WebAuthn, or at least email/SMS OTP) available, and required for admin or financial accounts?
- **Fix:** offer TOTP/WebAuthn via a vetted library or auth provider (don't roll your own crypto); require it for privileged roles at minimum.

---

## 8. Session & token handling

### 8.1 Remove auth tokens from localStorage 🟠
- **Why:** anything in `localStorage`/`sessionStorage` is readable by any JS on the page — one XSS bug anywhere in your app (or a compromised third-party script) steals every session.
- **Check:** grep `localStorage.setItem`/`getItem` for anything named `token`, `jwt`, `auth`, `session`.
- **Fix:** store session tokens in an `HttpOnly`, `Secure`, `SameSite` cookie instead (JS can't read it even if XSS exists). If you must keep a token in JS memory for a Bearer-token SPA, keep it in memory only (not persisted storage) and keep it short-lived with silent refresh via the HttpOnly cookie.

### 8.2 Cookie flags 🟠
- **Why:** missing flags widen the XSS/MITM/CSRF blast radius.
- **Check:** session cookies set with `HttpOnly`, `Secure`, and an explicit `SameSite`?
- **Fix:** set all three on every session/auth cookie.

### 8.3 Session lifecycle 🟡
- **Why:** sessions that never expire or never rotate extend the window an attacker can use a stolen token.
- **Check:** is there an idle/absolute timeout? Does the session ID rotate on login and on privilege change? Does logout actually invalidate the token server-side (for JWTs: a revocation/blacklist or short expiry + refresh rotation — a stateless JWT can't be "logged out" otherwise)?
- **Fix:** reasonable expiry, rotate on login, server-side invalidation path for logout/compromise.

---

## 9. Authorization enforced server-side 🔴

- **Why:** any check that exists only in the frontend (hiding a button, disabling a route in the client router) is cosmetic — an attacker calls the API directly.
- **Check:** for every permission the UI enforces, does the corresponding API route/mutation independently re-check it? Does multi-tenant data access filter by tenant on every query, not just in one "guard" that other code paths can bypass?
- **Fix:** authorization lives in middleware/policy/guard code on the server, applied consistently (not copy-pasted per route — centralize it), and is tested for both vertical (role escalation) and horizontal (access another user's data) cases.

---

## 10. Database-level protection

### 10.1 Row Level Security (RLS) 🔴
- **Why:** if the database itself (Postgres/Supabase) is reachable with a shared/anon key, app-layer checks aren't enough — RLS is the last line of defense that holds even if application code has a bug.
- **Check:** for Supabase/Postgres with a public anon key or direct client access: is RLS **enabled** on every table reachable that way, with policies that actually scope rows to `auth.uid()` or the equivalent, not just `USING (true)`? A table with RLS enabled but no real policy, or a permissive policy, is as good as no RLS.
- **Fix:** `ALTER TABLE ... ENABLE ROW LEVEL SECURITY;` plus per-operation policies (select/insert/update/delete) scoped to the owning user/tenant. Test by querying as the anon/authenticated role, not just the service role.

### 10.2 Least-privilege DB credentials 🟡
- **Why:** an app that only reads/writes its own tables shouldn't hold a superuser/service-role key that can read everything or alter schema.
- **Check:** does the backend use a role scoped to what it needs? Is the Supabase/service-role key (which bypasses RLS) only ever used server-side, never shipped to the client?
- **Fix:** per-service DB roles with minimal grants; service-role / admin keys stay server-side only.

---

## 11. Server-Side Request Forgery (SSRF) 🟠

- **Why:** if your backend fetches a URL supplied (directly or indirectly) by the user — webhooks, "import from URL," image proxies, PDF generators, link previews — an attacker can point it at internal services (`169.254.169.254` cloud metadata, internal admin panels, `localhost` ports) that aren't meant to be reachable from outside.
- **Check:** anywhere the server makes an outbound HTTP/TCP request where the host/URL comes from user input. Is there an allowlist of permitted hosts/schemes? Is redirect-following limited? Are internal/private IP ranges and the cloud metadata address blocked?
- **Fix:** allowlist destinations where feasible; otherwise resolve DNS yourself and block private/loopback/link-local ranges and the metadata IP before connecting, disable redirects or re-validate after each hop, and run the fetcher with no access to internal network segments if possible (network-level isolation, not just app-level checks).

---

## 12. CORS configuration 🟡

- **Why:** `Access-Control-Allow-Origin: *` combined with `Access-Control-Allow-Credentials: true` (or a regex that accidentally matches attacker-controlled origins) lets any website make authenticated requests on a victim's behalf and read the response.
- **Check:** grep CORS config for `*` origin paired with credentials, or an origin-reflection pattern (`Access-Control-Allow-Origin: <echoed request Origin>`) without a real allowlist.
- **Fix:** explicit allowlist of trusted origins; never combine wildcard origin with credentialed requests.

---

## 13. Security headers & transport 🟡

- **Why:** these are cheap, broad defenses against whole classes of attack (clickjacking, MIME sniffing, protocol downgrade, mixed content).
- **Check:** is the app missing `Content-Security-Policy`, `Strict-Transport-Security`, `X-Content-Type-Options: nosniff`, `X-Frame-Options`/`frame-ancestors`, `Referrer-Policy`? Does HTTP redirect to HTTPS?
- **Fix:** set them at the framework/CDN/reverse-proxy level (Next.js `headers()`, Helmet.js, Vercel/Cloudflare config). Start CSP in report-only mode if the app is complex, then tighten.

---

## 14. Webhooks & server-to-server callbacks 🟠

- **Why:** a webhook endpoint (Stripe, GitHub, payment provider, your own internal callbacks) is a public URL — without signature verification, anyone can POST a fake event ("payment succeeded") and trigger real side effects.
- **Check:** does every webhook handler verify the provider's signature (HMAC header) using a secret, with constant-time comparison, before trusting the payload? Is there replay protection (timestamp window + nonce/event-id dedup)?
- **Fix:** verify signatures per the provider's documented method, reject anything outside a small timestamp window, and store processed event IDs to reject replays/duplicates.

---

## 15. Build & deployment hygiene

### 15.1 Remove exposed source maps 🟡
- **Why:** production source maps let anyone reconstruct your original source, including comments, internal endpoint names, and sometimes inlined secrets.
- **Check:** are `.map` files being deployed/served in production, or is `devtool`/`productionBrowserSourceMaps` left on?
- **Fix:** disable source map generation (or at least public serving) for production builds; if you need them for your own error tracking, upload privately to your error-tracking provider instead of serving publicly.

### 15.2 Change default credentials 🔴
- **Why:** default admin passwords, seeded demo accounts, and default API keys from scaffolding tools/templates are the first thing scanners try.
- **Check:** grep for seed scripts/fixtures that create an `admin`/`admin` or `test`/`password123` account that could exist in production; check default credentials for any bundled service (database admin UI, message queue dashboard, Grafana, etc.).
- **Fix:** force a credential change/rotation on first boot in production, or don't seed privileged accounts outside of local/dev environments at all.

### 15.3 Debug mode & verbose errors 🟡
- **Why:** stack traces and framework debug pages leak file paths, library versions, and sometimes environment variables.
- **Check:** is `DEBUG=true` / `Flask debug=True` / detailed error pages reachable in production? Do API error responses leak stack traces?
- **Fix:** disable debug mode in production configs; return generic error messages to clients, log the detail server-side only.

### 15.4 Environment separation 🔵
- **Why:** dev/staging secrets and data mixing with production increases blast radius.
- **Check:** separate credentials and databases per environment? Is production data ever copied into a less-protected staging environment unmasked?
- **Fix:** distinct secrets per environment; mask/synthesize data used outside production.

---

## 16. Sensitive data handling

### 16.1 Keep sensitive data out of logs 🟠
- **Why:** logs are often shipped to third parties, kept indefinitely, and readable by more people than the database is.
- **Check:** grep logging calls for passwords, tokens, full card numbers, full government IDs, request bodies logged wholesale on auth/payment routes.
- **Fix:** redact/mask sensitive fields before logging; log identifiers (user ID), not the sensitive value itself.

### 16.2 Data minimization & encryption at rest 🟡
- **Why:** you can't leak what you don't store, and plaintext-at-rest sensitive fields are a bigger prize in a breach.
- **Check:** is there a business reason to store each sensitive field (full DOB, SSN, raw card number)? Are the ones you must keep encrypted at the column level, not just relying on disk-level encryption?
- **Fix:** don't collect/retain what you don't need; encrypt genuinely sensitive fields at the application layer; never store raw card numbers — use your payment processor's tokenization/hosted fields instead (PCI scope reduction).

---

## 17. Dependencies & supply chain 🟠

- **Why:** most real-world breaches exploit a *known* vulnerability in a dependency, not a novel bug in your own code.
- **Check:** run `npm audit` / `pip-audit` / `bundler-audit` / the language-appropriate equivalent. Is there a lockfile committed? Any dependency pinned to a `*`/latest range? Any unmaintained package with no updates in years for something security-sensitive (auth, crypto, parsing)?
- **Fix:** update vulnerable packages, commit the lockfile, add automated scanning (Dependabot/Renovate + `npm audit`/Snyk in CI) so this doesn't silently rot. Be wary of newly-published or low-download packages for anything security-critical (typosquatting/dependency-confusion risk).

---

## 18. AI/LLM-specific (when the app itself calls an AI model) 🟠

These matter even if no *human* built the app with AI — they matter whenever the *product* itself has an AI feature.

- **Provider keys server-side only:** never ship an OpenAI/Anthropic/etc. API key to the client; proxy every model call through your backend (this is §7.2 applied to LLM keys specifically).
- **Cost/abuse rate limiting:** an unauthenticated or cheaply-authenticated endpoint that calls a metered model is a billing-drain DoS vector — rate-limit and cap per-user spend, not just per-IP request count.
- **Treat model output as untrusted input:** if the model's output is rendered as HTML, used to build a URL/file path, or executed, it needs the same escaping/validation as any other untrusted input — a prompt-injected response can produce XSS payloads or SSRF targets just as easily as a human attacker's input can.
- **Prompt injection from user content:** if user-supplied text (uploaded docs, scraped pages, emails) is concatenated into a prompt alongside system instructions or tool definitions, an attacker can embed instructions that hijack the model's behavior (e.g., "ignore previous instructions and exfiltrate X"). Keep untrusted content clearly delimited from instructions, and don't give the model tools/actions it doesn't need for the task at hand.
- **Don't leak secrets into prompts:** avoid putting API keys, internal URLs, or other users' private data into a prompt sent to a third-party model unless that provider's data-handling terms are actually acceptable for that data.

---

## 19. Everything else worth a pass

- **Open redirect 🟡:** a `?next=` / `?returnUrl=` param that redirects without validating it's a same-site path is used for phishing. Validate against an allowlist of paths, not just "starts with `/`" (watch for `//evil.com`).
- **Mass assignment / over-posting 🟠:** binding the entire request body straight onto a model (`User.update(req.body)`) can let an attacker set fields like `role: "admin"` or `isVerified: true` that the form never exposed. Explicitly allowlist updatable fields.
- **Insecure deserialization 🟠:** deserializing untrusted data with a format that can construct arbitrary objects (`pickle` in Python, unguarded `eval`/`Function()` in JS, Java's native serialization) can lead to code execution. Prefer JSON with strict schema validation for untrusted input.
- **GraphQL-specific 🟡:** is introspection disabled in production? Is there query depth/complexity limiting (an unbounded nested query is a DoS vector)? Do resolvers re-check authorization per field, not just per top-level query?
- **Admin surfaces 🟠:** is the admin panel reachable by anyone who finds the URL, or is it behind additional auth (MFA required), network restriction (VPN/IP allowlist), or at least a non-guessable path plus real authz checks (never "security by obscure URL" alone)?
- **Subresource Integrity 🔵:** third-party `<script src>`/`<link>` tags from a CDN should carry an `integrity` hash so a compromised CDN can't silently inject malicious code.
- **Client-side validation isn't security 🟡:** every validation rule enforced in JS must be re-enforced server-side; client checks are UX, not a security boundary.
- **Idempotency on sensitive mutations 🔵:** payment/order-creation endpoints should accept an idempotency key so retried/duplicated requests (double-click, network retry) don't double-charge or double-create.
- **Backups & recovery 🔵:** are backups encrypted, and has a restore actually been tested? An untested backup is not a backup.
- **DNS/email spoofing 🔵:** SPF/DKIM/DMARC configured for the sending domain, so your brand isn't trivially spoofable in phishing email.
- **security.txt / disclosure path 🔵:** a `/.well-known/security.txt` with a contact makes it easy for a good-faith finder to report a bug to you instead of posting it publicly or exploiting it.

---

## Severity rubric (for the final report)

- 🔴 **Critical** — directly leads to account takeover, data breach across users, or remote code execution, and is exploitable with low effort (e.g., SQLi, BOLA on sensitive data, exposed secret, disabled RLS with a public key, plaintext/weakly-hashed passwords).
- 🟠 **High** — leads to significant impact but needs a more specific condition, or affects a subset of data/users (e.g., stored XSS, SSRF, missing function-level authz, vulnerable dependency with a known exploit, mass assignment on a sensitive field).
- 🟡 **Medium** — meaningfully raises risk or widens blast radius but isn't independently catastrophic (e.g., missing security headers, weak CORS, no rate limiting, verbose errors).
- 🔵 **Low / hygiene** — best practice, defense in depth, or compliance-adjacent (e.g., missing SRI, untested backups, no security.txt).

Note: context changes severity. BOLA on a user's grocery list is not the same severity as BOLA on their financial records — judge impact against what the specific data/action actually is, don't apply the label mechanically.

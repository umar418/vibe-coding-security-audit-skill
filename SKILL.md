---
name: vibe-coding-security-audit-skill
description: Run a systematic security audit of a web app or website's codebase against an OWASP-style checklist (SQL/command injection, XSS, CSRF, broken object/function-level authorization, file upload handling, rate limiting, JWT/secret management, password hashing, MFA, CORS, security headers, session/cookie handling, Row Level Security, SSRF, webhook signature verification, exposed source maps, default credentials, secrets-in-logs, vulnerable dependencies, and more). Use this whenever the user wants their app or site reviewed for security issues, wants to "harden" it, is about to ship/deploy/launch and wants a pre-launch check, asks "is this secure" or "what am I missing security-wise," mentions a security checklist or pentest-lite pass, or — especially — when the app was mostly built by an AI coding tool (vibe-coded) and the user has limited security background themselves, since that's exactly the gap this skill exists to cover. Trigger even if they only name one or two concerns (e.g. "check for SQL injection") — run the fuller pass and say so, since issues in this space cluster together.
---

# Web app security audit for AI-built ("vibe coded") apps

## Why this skill exists

Apps built quickly with an AI coding assistant tend to get the happy path right and skip everything that doesn't show up when you click around the UI yourself: authorization checks, rate limits, header hygiene, RLS policies, secret handling. None of that is exotic — it's the same handful of OWASP Top 10 categories that show up in almost every real breach. This skill turns that into a repeatable pass instead of relying on remembering a long list.

The person running this often isn't a security engineer. Write findings so a non-expert can act on them: what's wrong, concretely, what it would let an attacker do, and the specific fix — not jargon for its own sake.

## Workflow

1. **Identify the stack.** Framework, database/auth provider, hosting. This decides which parts of `references/stack-notes.md` apply (Next.js/Vercel, Supabase, Firebase, plain Node/Express, WordPress/PHP, etc.) — read the relevant section(s) before diving in, since the same checklist item lives in a different place per stack.

2. **Run the quick scan for a first pass.**
   ```
   scripts/quick_scan.sh <path-to-project>
   ```
   This is a cheap grep sweep, not a verdict — it surfaces candidate locations across the categories below. It will miss hand-rolled variants of a bug and will also flag safe code that happens to match a pattern. Every hit needs your own read of the surrounding code; a clean scan does **not** mean the app is clean, especially for logic bugs like broken object-level authorization that no regex can find.

3. **Work through the full checklist** in `references/checklist.md` — it's organized into 19 numbered sections (injection, XSS, CSRF, file uploads, broken object/function-level authorization, rate limiting, secrets & key management, session/token handling, server-side authorization, database-level protection/RLS, SSRF, CORS, security headers, webhooks, build/deploy hygiene, sensitive data handling, dependencies, AI/LLM-specific concerns, and a catch-all of everything else). For each section relevant to this app (skip ones that genuinely don't apply, e.g. CSRF checks for a pure Bearer-token API with no cookies — but say so explicitly rather than silently skipping), decide: clean, or a finding.
   - Don't stop at the listed items if something doesn't fit a category but is clearly a security problem — the checklist covers the common, recurring cases, not every possible bug. Use OWASP Top 10 / OWASP ASVS as the backstop for anything that falls outside it.
   - BOLA/IDOR (§5) and server-side authorization (§9) are the ones automated scanning misses entirely and that "it built and the demo worked" never tests — give them real attention, tracing actual request handlers, not just skimming for a pattern.

4. **Classify severity** using the rubric at the bottom of `references/checklist.md` (🔴 Critical / 🟠 High / 🟡 Medium / 🔵 Low), judged against what the specific data or action actually is — not applied mechanically by category.

5. **Decide what to fix vs. flag.** For anything you can fix with a clear, contained change (add a missing header, parameterize a query, add server-side ownership checks, enable RLS with a sane policy, move a secret out of client code), make the fix and say what you changed. For anything that needs a product decision (which MFA provider, whether a feature even needs that data retained, infrastructure/network changes outside the repo), flag it clearly with a recommended direction rather than guessing and changing it silently — this is the same bar as any other code change: don't refactor beyond what's needed to close the hole.

6. **Write the report** using `references/report-template.md`. Lead with the summary and critical findings. Explicitly state what was *not* covered (infra/network config, live dynamic testing, individual CVE verification beyond an audit command) so "audited" doesn't get read as a stronger guarantee than what actually happened.

## A few things worth saying out loud to the user

- This is a code-review pass, not a penetration test — it won't catch everything a live attacker with more time would, and it can't verify infrastructure/network-level controls (firewalls, cloud IAM, DNS) just by reading the repo. Say this rather than letting "audit complete" imply more than it does.
- If you find something actively exploitable and already in production (exposed secret, disabled RLS on sensitive data, default admin credentials), lead with that and suggest rotating/fixing it immediately rather than burying it in a long list.
- Fixing everything in one pass can be a lot of changed files — offer to prioritize (fix criticals now, list the rest) rather than silently making a huge diff, same as you would for any other large change.

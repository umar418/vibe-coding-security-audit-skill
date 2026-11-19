# Vibe Coding Security Audit Skill

**A free, open-source security audit skill for apps built with AI coding tools. It works with Claude Code, OpenAI Codex, and any agent that supports the open Agent Skills (`SKILL.md`) format.**

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Agent Skills](https://img.shields.io/badge/format-Agent%20Skills%20(SKILL.md)-blue)](https://agentskills.io/specification)
[![Claude Code](https://img.shields.io/badge/works%20with-Claude%20Code-orange)](https://code.claude.com/docs/en/skills)
[![Codex](https://img.shields.io/badge/works%20with-OpenAI%20Codex-black)](https://developers.openai.com/codex/skills)
[![OWASP](https://img.shields.io/badge/based%20on-OWASP%20Top%2010-red)](https://owasp.org/www-project-top-ten/)

AI coding assistants are good at building an app that *works*. They're much worse at building one that's *safe*. This skill gives your AI agent a structured, OWASP-based security checklist and a step-by-step audit workflow. You get a prioritized findings report, with the fixes applied wherever they're safe and contained, before you ship.

---

## Table of contents

- [Why this exists](#why-this-exists)
- [What it checks](#what-it-checks)
- [Quick start](#quick-start)
- [How to use it](#how-to-use-it)
- [How the audit works](#how-the-audit-works)
- [Example output](#example-output)
- [Supported stacks](#supported-stacks)
- [Severity levels](#severity-levels)
- [Repository structure](#repository-structure)
- [Limitations](#limitations)
- [FAQ](#faq)
- [Contributing](#contributing)
- [License](#license)

---

## Why this exists

"Vibe coding" means describing what you want and letting an AI write most of the code. It gets products out the door fast. It also tends to skip everything that doesn't show up when you click around the UI yourself:

- an API that returns **any** user's data if you change the ID in the URL
- a Supabase database with **Row Level Security turned off**
- a secret API key shipped **inside the browser bundle**
- login and password-reset forms with **no rate limiting**
- auth tokens sitting in **`localStorage`**, one XSS bug away from being stolen
- CORS set to `*` "to make it work", and never tightened

None of these are exotic. They're the same OWASP Top 10 categories behind most real breaches. This skill turns them into a repeatable pass your AI agent runs for you. It's written so that someone without a security background can understand every finding and act on it.

## What it checks

19 categories, each with **why it matters**, **how to check it** and **how to fix it** ([full checklist](references/checklist.md)):

| # | Category | Key checks |
|---|---|---|
| 1 | Injection | SQL, NoSQL, command and server-side template injection; unsafe ORM raw-query escape hatches |
| 2 | Cross-site scripting (XSS) | `dangerouslySetInnerHTML`, `v-html`, disabled template autoescaping, stored and reflected XSS |
| 3 | CSRF | Token or `SameSite` protection on every state-changing cookie-session route |
| 4 | File uploads | Content-based type checks, size limits, private storage, randomized names, SVG sanitizing |
| 5 | Broken object & function-level authorization | IDOR/BOLA ownership checks, admin-only actions re-checked on the server |
| 6 | Rate limiting & abuse | Login, signup, password reset, OTP and paid-API endpoints; lockout and CAPTCHA |
| 7 | Secrets & keys | Strong JWT secrets, server-side-only API keys, no secrets in git, bcrypt/argon2 hashing, MFA |
| 8 | Sessions & tokens | No tokens in `localStorage`, `HttpOnly`/`Secure`/`SameSite` cookies, expiry and rotation |
| 9 | Server-side authorization | Every UI permission enforced again in the API, tenant scoping on every query |
| 10 | Database protection | Row Level Security on and with real policies, least-privilege DB roles, service keys kept server-side |
| 11 | SSRF | Allowlisted outbound URLs, private IP and cloud-metadata blocking, redirect handling |
| 12 | CORS | No wildcard origin combined with credentials, no reflected-origin allowlists |
| 13 | Security headers & HTTPS | CSP, HSTS, `nosniff`, frame protection, Referrer-Policy, HTTP to HTTPS redirect |
| 14 | Webhooks | HMAC signature verification, timestamp window, replay protection |
| 15 | Build & deploy hygiene | No public source maps, no default credentials, debug mode off, separate environments |
| 16 | Sensitive data | Nothing sensitive in logs, data minimization, field-level encryption, no raw card storage |
| 17 | Dependencies & supply chain | `npm audit` / `pip-audit`, committed lockfiles, typosquatting awareness |
| 18 | AI / LLM features | Provider keys server-side, cost-abuse limits, model output treated as untrusted, prompt injection |
| 19 | Everything else | Open redirects, mass assignment, insecure deserialization, GraphQL limits, admin panels, SRI, backups, SPF/DKIM/DMARC, `security.txt` |

## Quick start

### 1. Clone it

```bash
git clone https://github.com/umar418/vibe-coding-security-audit-skill.git
```

### 2. Install it for your AI coding tool

**Claude Code**, for all your projects:

```bash
mkdir -p ~/.claude/skills
ln -s "$(pwd)/vibe-coding-security-audit-skill" ~/.claude/skills/vibe-coding-security-audit-skill
```

**Claude Code**, for one project only:

```bash
mkdir -p /path/to/your/project/.claude/skills
ln -s "$(pwd)/vibe-coding-security-audit-skill" /path/to/your/project/.claude/skills/vibe-coding-security-audit-skill
```

**OpenAI Codex CLI**, for all your projects:

```bash
mkdir -p ~/.agents/skills
ln -s "$(pwd)/vibe-coding-security-audit-skill" ~/.agents/skills/vibe-coding-security-audit-skill
```

**OpenAI Codex CLI**, for one project only:

```bash
mkdir -p /path/to/your/project/.agents/skills
ln -s "$(pwd)/vibe-coding-security-audit-skill" /path/to/your/project/.agents/skills/vibe-coding-security-audit-skill
```

**Any other agent** (Cursor, Windsurf, Gemini CLI, Aider, etc.): if it supports the Agent Skills format, put the folder in its skills directory. If it doesn't, tell it to read `SKILL.md` and follow it, or paste `SKILL.md` and `references/checklist.md` into its instructions. Everything is plain Markdown, so no special feature is required.

> Using a symlink instead of copying means `git pull` inside the cloned folder updates the skill everywhere it's installed.

### 3. Run it

Open your project in your AI coding tool and ask something like:

```
Audit this app for security issues before I launch it.
```

## How to use it

The skill triggers automatically when your request matches what it covers. Any of these work:

- "Run a full security audit on this codebase."
- "Is this app safe to launch? I built most of it with AI."
- "Check my Next.js + Supabase app for security holes."
- "Harden this API before I deploy it."
- "Check for SQL injection." (It runs the full pass, since these issues tend to come in clusters, and tells you so.)
- "Review just the auth and payment routes for security problems."

You can also run the bundled scanner on its own, without an AI agent, for a quick first look:

```bash
./scripts/quick_scan.sh /path/to/your/project
```

It's a fast grep-based triage that points at files worth reading closely. It's not a verdict on its own (see [Limitations](#limitations)).

## How the audit works

1. **Identify the stack.** Framework, database or auth provider, and hosting decide where each issue usually lives ([stack notes](references/stack-notes.md)).
2. **Run the quick scan.** A grep sweep surfaces candidate locations across the categories.
3. **Work through the full checklist.** The agent goes through all 19 categories and reads the actual request handlers. That matters most for authorization bugs, which no pattern-matcher can find.
4. **Rate each finding** Critical, High, Medium or Low, based on what the affected data or action actually is.
5. **Fix or flag.** Contained fixes (a missing header, a string-built query, a missing ownership check, RLS turned off) get applied. Anything that needs a product decision gets flagged with a recommended direction.
6. **Write the report**, using the [report template](references/report-template.md). It includes an explicit list of what was *not* covered.

## Example output

```markdown
### 🔴 Any logged-in user can read any other user's invoices

- **Category:** 5. Broken Object Level Authorization
- **Location:** `app/api/invoices/[id]/route.ts:14`
- **Issue:** The handler loads the invoice with `where: { id }` only. Changing the ID in
  `GET /api/invoices/123` returns another customer's invoice, including their address and amount.
- **Impact:** Every customer's billing data is readable by any signed-in account.
- **Fix:** Scope the lookup to the caller: `where: { id, userId: session.user.id }`, and return 404 when nothing matches.
- **Status:** Fixed in this session
```

See [examples/sample-report.md](examples/sample-report.md) for a complete example report.

## Supported stacks

The checklist works for any web stack. These stacks also get specific guidance in [references/stack-notes.md](references/stack-notes.md):

- **Next.js / Vercel**: `NEXT_PUBLIC_` secret leaks, Server Actions as public endpoints, middleware matcher gaps, source maps
- **Supabase**: Row Level Security, service-role key exposure, public storage buckets
- **Firebase**: permissive Firestore, Realtime Database and Storage rules, HTTP Cloud Functions
- **Node.js / Express**: Helmet, CORS, rate limiting, CSRF middleware, ORM raw-query escape hatches
- **WordPress / PHP**: default admin credentials, outdated plugins, PHP execution in uploads

## Severity levels

| Level | Meaning | Examples |
|---|---|---|
| 🔴 Critical | Low-effort account takeover, data breach across users, or remote code execution | SQL injection, IDOR on sensitive data, leaked secret, RLS off with a public key |
| 🟠 High | Serious impact under a specific condition, or affecting a subset of users | Stored XSS, SSRF, missing admin authorization, mass assignment |
| 🟡 Medium | Raises risk or widens blast radius | Missing security headers, loose CORS, no rate limiting |
| 🔵 Low | Hygiene and defense in depth | Missing SRI, untested backups, no `security.txt` |

## Repository structure

```
vibe-coding-security-audit-skill/
├── SKILL.md                    The skill: when it triggers and the audit workflow
├── references/
│   ├── checklist.md            The full 19-category checklist (why / how to check / how to fix)
│   ├── stack-notes.md          Stack-specific guidance (Next.js, Supabase, Firebase, Express, WordPress)
│   └── report-template.md      Format of the final findings report
├── scripts/
│   └── quick_scan.sh           Grep-based first-pass scanner
├── examples/
│   └── sample-report.md        A complete example audit report
├── CHANGELOG.md
├── CONTRIBUTING.md
└── LICENSE
```

## Limitations

- **This is a code review, not a penetration test.** It reads your code. It doesn't attack a running app, and it can't verify infrastructure you can't see from the repo (cloud IAM, firewalls, DNS).
- **`quick_scan.sh` is triage.** It will miss hand-written variants of a bug and flag some safe code. Treat every hit, and every "no hits", as a pointer to code that needs reading.
- **A clean report isn't a guarantee.** For apps that handle money, health data or other sensitive personal data, a professional security review is still worth it. This skill gets you to that review with the obvious holes already closed.

## FAQ

**Do I need to be a security expert to use this?**
No. That's the point. Findings explain what's wrong, what an attacker could do, and exactly how to fix it, in plain language.

**Will it change my code without asking?**
It applies small, contained fixes and reports each one. For larger or product-level changes (choosing an MFA provider, changing infrastructure) it flags the issue and recommends a direction instead. You can also tell it "report only, don't change anything."

**Does it work if my app wasn't vibe coded?**
Yes. The checklist is ordinary web application security. It's just written with the gaps AI-built apps tend to have in mind.

**Does it send my code anywhere?**
The skill itself is just Markdown files and a local shell script. Your code goes wherever your AI coding tool normally sends it, and nowhere else.

**Which AI tools does it support?**
Claude Code and OpenAI Codex natively, through the shared Agent Skills format. Any other agent can use it by reading `SKILL.md`.

## Contributing

Contributions are welcome, especially:

- new checklist items, or better "how to check" guidance
- stack notes for frameworks not covered yet (Django, Rails, Laravel, SvelteKit, Remix, etc.)
- better detection patterns in `quick_scan.sh`

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE). Free to use, modify and share, including commercially.

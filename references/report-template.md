# Security audit report — {project name}

**Date:** {date}
**Scope:** {what was reviewed — whole repo, specific feature, specific routes}
**Stack detected:** {e.g. Next.js + Supabase + Vercel}

## Summary

{2-4 sentences: overall posture, the most urgent thing to fix, how many findings at each severity}

| Severity | Count |
|---|---|
| 🔴 Critical | {n} |
| 🟠 High | {n} |
| 🟡 Medium | {n} |
| 🔵 Low | {n} |

## Findings

Ordered by severity, most urgent first. One entry per finding — don't bundle unrelated issues together even if they're the same category.

### 🔴 {short title}

- **Category:** {checklist section, e.g. "5. Broken Object Level Authorization"}
- **Location:** `{file path}:{line}` (or route/endpoint if not a single location)
- **Issue:** {what's wrong, concretely — not just "missing authz" but what request, with what input, produces what bad outcome}
- **Impact:** {what an attacker actually gets}
- **Fix:** {specific change — code sketch if it's not obvious, not just "add validation"}
- **Status:** {Fixed in this session / Flagged for you to fix / Needs your decision — see note}

{repeat per finding}

## Not checked / out of scope

{Be explicit about what the audit did NOT cover — e.g. "infrastructure/network config wasn't reviewed since this was a code-only pass", "third-party dependency CVEs weren't individually verified beyond running `npm audit`", "no dynamic/runtime testing (no live requests were sent against a running instance)". A reader should know the edges of what "audited" means here.}

## Recommended next steps

{Ordered by priority. Distinguish "fix before any real users touch this" from "fix soon" from "nice to have."}

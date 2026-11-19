#!/usr/bin/env bash
# Quick grep-based first pass for the vibe-coding-security-audit-skill.
#
# This is a cheap, noisy triage pass — NOT a verdict. It exists to point you at files
# worth reading closely; every hit still needs human judgment against references/checklist.md,
# and the absence of a hit proves nothing (hand-rolled patterns dodge any fixed regex).
#
# Usage: scripts/quick_scan.sh [path-to-scan]   (defaults to current directory)

set -uo pipefail
ROOT="${1:-.}"
EXCLUDE_DIRS='(node_modules|\.git|\.next|dist|build|vendor|\.venv|venv|__pycache__|\.turbo|coverage)'

say() { printf '\n## %s\n' "$1"; }

grep_hits() {
  # grep_hits <label> <pattern> [extra grep args...]
  local label="$1" pattern="$2"; shift 2
  local hits
  hits=$(grep -rnE --binary-files=without-match "$@" "$pattern" "$ROOT" 2>/dev/null \
    | grep -vE "/$EXCLUDE_DIRS/")
  if [ -n "$hits" ]; then
    printf -- '- %s\n' "$label"
    echo "$hits" | sed 's/^/    /' | head -n 30
    local total
    total=$(echo "$hits" | wc -l | tr -d ' ')
    if [ "$total" -gt 30 ]; then
      printf '    ... and %d more matches\n' "$((total - 30))"
    fi
  fi
}

echo "# Quick scan: $ROOT"
echo "_Generated $(date -u +%Y-%m-%dT%H:%M:%SZ). Cross-reference every hit with references/checklist.md before reporting it as a finding._"

say "1. Possible raw SQL / string-built queries (§1.1)"
grep_hits "Raw query with interpolation" '(query|execute)\s*\(\s*(`[^`]*\$\{|f"[^"]*\{|f'"'"'[^'"'"']*\{|".*"\s*\+)' -P
grep_hits "ORM raw-SQL escape hatches" '\.(raw|queryRawUnsafe|literal)\s*\('

say "2. Possible XSS sinks (§2)"
grep_hits "dangerouslySetInnerHTML / v-html / innerHTML" '(dangerouslySetInnerHTML|v-html|\.innerHTML\s*=)'
grep_hits "Autoescaping disabled in templates" '(\|\s*safe|\{\{\{|<%-)'

say "3. Command execution (§1.3)"
grep_hits "Shell exec calls" '\b(child_process\.exec\b|os\.system\(|subprocess\.\w+\(.*shell\s*=\s*True)'

say "4. Secrets possibly hard-coded (§7)"
grep_hits "Hard-coded key-shaped secrets" '(sk-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{20,}|secret\s*[:=]\s*["'"'"'][A-Za-z0-9+/_-]{16,})' -i -P
grep_hits "Public-prefixed env var holding something secret-shaped" '(NEXT_PUBLIC_|VITE_|REACT_APP_)[A-Z_]*(SECRET|PRIVATE|SERVICE_ROLE|KEY)\b' -i

say "5. Weak password hashing (§7.4)"
grep_hits "MD5/SHA1/plain SHA256 near 'password'" '(md5|sha1)\s*\(' -i

say "6. Auth tokens in localStorage (§8.1)"
grep_hits "localStorage used for tokens" 'localStorage\.(setItem|getItem)\s*\(\s*["'"'"'](token|jwt|auth|session)'  -i

say "7. CORS wildcard with credentials (§12)"
grep_hits "Wildcard origin" 'Access-Control-Allow-Origin.*\*'
grep_hits "Credentialed CORS" 'Access-Control-Allow-Credentials.*true'

say "8. Webhook handlers (§14) — verify these check a signature"
grep_hits "Likely webhook routes" '(webhook|/hooks?/)' -il

say "9. Source maps in production build config (§15.1)"
grep_hits "Source maps explicitly enabled" '(productionBrowserSourceMaps|devtool)\s*[:=]\s*(true|["'"'"']source-map)'

say "10. Debug mode left on (§15.3)"
grep_hits "Debug flags" '(DEBUG\s*=\s*True|debug\s*:\s*true|app\.debug\s*=\s*True)'

say "11. Default/seeded admin credentials (§15.2)"
grep_hits "Seeded admin-like accounts" '(admin.{0,20}(password|pass)\s*[:=]\s*["'"'"'](admin|password|123|test))' -i

say "12. .env files tracked by git"
if [ -d "$ROOT/.git" ]; then
  tracked=$(git -C "$ROOT" ls-files | grep -E '^\.env($|\.)' || true)
  if [ -n "$tracked" ]; then
    echo "- .env file(s) tracked in git history:"
    echo "$tracked" | sed 's/^/    /'
  fi
fi

say "13. Dependency audit"
if [ -f "$ROOT/package-lock.json" ] || [ -f "$ROOT/package.json" ]; then
  echo "- Node project detected. Run: (cd \"$ROOT\" && npm audit --omit=dev)"
fi
if [ -f "$ROOT/requirements.txt" ] || [ -f "$ROOT/pyproject.toml" ]; then
  echo "- Python project detected. Run: pip-audit -r \"$ROOT/requirements.txt\" (or against your resolved environment)"
fi

echo
echo "Done. This output is a map of where to look, not a findings list — read each hit in context before writing it up."

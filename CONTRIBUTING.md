# Contributing

Thanks for helping make AI-built apps safer. Contributions of every size are welcome.

## Good first contributions

- **New stack notes.** Add a section to `references/stack-notes.md` for a framework that isn't covered yet (Django, Rails, Laravel, SvelteKit, Remix, Astro, FastAPI, etc.). Say where each checklist item lives in that stack and which defaults are unsafe.
- **Better detection patterns.** Improve `scripts/quick_scan.sh`, especially to reduce false positives or catch common variants that are currently missed.
- **Checklist improvements.** Clearer "how to check" steps, more precise fixes, or a missing category.
- **Typos and clarity fixes.** The audience includes people without a security background, so plain language matters.

## Guidelines

- **Keep `SKILL.md` short.** It loads into the agent's context every time the skill runs. Detail belongs in `references/`.
- **Every checklist item needs three parts:** *why it matters*, *how to check it*, and *how to fix it*.
- **Explain, don't just command.** "Do X, because Y" helps the agent handle edge cases. A bare "ALWAYS do X" doesn't.
- **No exploit code.** Describe vulnerabilities well enough to find and fix them. Don't include working attack payloads beyond minimal, well-known examples like `' OR 1=1`.
- **Keep `quick_scan.sh` dependency-free.** It should run with plain `bash`, `grep` and `sed` on macOS and Linux.

## Making a change

1. Fork the repo and create a branch.
2. Make your change.
3. If you changed `quick_scan.sh`, run it on a real project and check that it still runs cleanly:
   ```bash
   ./scripts/quick_scan.sh /path/to/some/project
   ```
4. Add a line to `CHANGELOG.md` under **Unreleased**.
5. Open a pull request that explains what changed and why.

## Reporting a problem

Open an issue if:
- the skill missed a real vulnerability it should have caught,
- the skill flagged something that wasn't a problem, or
- an install path for Claude Code, Codex or another tool has changed.

Include the stack and, if you can, a minimal code example.

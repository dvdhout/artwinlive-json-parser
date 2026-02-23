# Source-Control Best Practices (Artwin)

## Branching

- Keep `main` always deployable and stable.
- Create short-lived feature branches per task, for example:
  - `feature/parser-improvements`
  - `chore/context-updates`
- Rebase or merge `main` frequently to reduce drift.

## Commit discipline

- Make small, focused commits (one logical change per commit).
- Write clear commit messages with intent + scope.
- Prefer conventional style:
  - `feat: add public-only parser filter`
  - `fix: handle empty venue fields`
  - `docs: add source-control context`
  - `chore: update gitignore for generated output`

## Pull request hygiene

- Open PRs early and keep them small.
- Include in PR description:
  - What changed
  - Why it changed
  - How it was tested
  - Any follow-up work
- Request review before merge for non-trivial changes.

## Protecting history

- Avoid force-push on shared branches.
- Never rewrite published `main` history.
- Tag meaningful milestones (`v1.0.0`, `parser-v1`).

## Quality gates

- Run parser locally before commit:
  - `powershell -ExecutionPolicy Bypass -File .\scripts\parse-artwin-widget.ps1 -NoExport`
- Verify generated files are not accidentally committed.
- Keep `output/` ignored in `.gitignore`.

## Repository conventions for this project

- `context/` contains conversation and requirements context.
- `scripts/` contains operational and parsing scripts.
- `output/` is generated data and should stay out of git history.

## Security and data handling

- Do not commit secrets, tokens, or personal credentials.
- Treat external payloads as untrusted input; validate parsing paths.
- Pin script behavior with explicit parameters when automating.

## Recommended merge strategy

- Use squash merge for feature branches to keep `main` history clean.
- Keep commit titles in imperative mood and under ~72 characters.

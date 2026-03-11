# Contributing to Termite Protocol

Thanks for helping improve Termite Protocol.

## Good ways to contribute

- Improve onboarding: README, `QUICKSTART.md`, examples, diagrams, FAQs.
- Reproduce or extend experiments in `audit-packages/` and document the results.
- Report bugs in installation, upgrades, signal claiming, or docs.
- Improve contributor experience: issue templates, labels, release notes, support docs.

## Before opening an issue

- Use GitHub Discussions for questions, usage help, and design exploration.
- Use GitHub Issues for confirmed bugs, scoped feature requests, and tasks with a clear outcome.
- Read `SUPPORT.md` and `SECURITY.md` first if your question is about support or a vulnerability.

## Local workflow

1. Create a branch from `main`.
2. Make focused changes.
3. Update docs when behavior or onboarding changes.
4. Run the relevant validation steps.
5. Open a pull request with context, risk, and verification notes.

## Validation

For documentation-only changes:

```bash
bash -n install.sh
tmp_dir=$(mktemp -d)
bash install.sh "$tmp_dir"
(cd "$tmp_dir" && ./scripts/field-arrive.sh && ./scripts/field-pulse.sh && sqlite3 .termite.db "select id,status,title from signals;")
rm -rf "$tmp_dir"
```

If you changed templates or scripts, also run targeted shell syntax checks:

```bash
bash -n install.sh templates/scripts/*.sh templates/scripts/hooks/* templates/claude-plugin/scripts/*.sh
```

## Pull request checklist

- The change is scoped and avoids unrelated cleanup.
- New user-facing behavior is reflected in `README.md`, `README.zh-CN.md`, or `QUICKSTART.md`.
- Release-impacting changes are noted in `CHANGELOG.md`.
- Install or onboarding changes include a smoke-test result.
- Security-sensitive changes explain risk and mitigation.

## Documentation conventions

- Keep English and Chinese entry docs aligned when changing positioning or onboarding.
- Prefer short commands that users can copy-paste.
- Link to concrete files in this repository instead of describing them vaguely.

## Looking for a first contribution?

Start with issues labeled `good first issue`, `documentation`, or `help wanted`.

## Code of Conduct

By participating in this project, you agree to follow `CODE_OF_CONDUCT.md`.

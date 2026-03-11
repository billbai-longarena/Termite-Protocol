# Termite Protocol Quick Start / 白蚁协议快速上手

This guide gets a fresh project from zero to a successful first arrival.

本文档帮助你在一个全新目录里完成安装、创世、首次验证。

## 1. Fastest path

```bash
mkdir termite-demo && cd termite-demo
curl -fsSL https://raw.githubusercontent.com/billbai-longarena/Termite-Protocol/main/install.sh | bash
./scripts/field-arrive.sh
```

If this works, you should see a generated colony scaffold plus an initial signal stored in the local SQLite field.

如果执行成功，你会看到协议脚手架和一个初始信号。

## 2. What the installer does

`install.sh` will:

- copy protocol templates into your current project
- create `signals/` runtime directories
- install protocol scripts and git hooks
- write entry files such as `CLAUDE.md` and `AGENTS.md`
- prepare the repo for the first `.birth` snapshot

## 3. Verify the first run

Run these checks after `field-arrive.sh`:

```bash
ls -la
./scripts/field-pulse.sh
sqlite3 .termite.db "select id,status,title from signals;"
```

You should now have:

- `BLACKBOARD.md`
- `.birth`
- an initial signal row in `.termite.db`, such as `S-001 | open | ...`
- pulse output reporting at least one active signal
- `scripts/` with field utilities installed

## 4. What happened during genesis

On the first arrival, `scripts/field-arrive.sh` checks whether the project already has a blackboard and active signals.

If not, it triggers `scripts/field-genesis.sh`, which will:

1. detect the project environment
2. create `BLACKBOARD.md`
3. create an initial `EXPLORE` signal
4. leave enough context for the next agent to continue

## 5. Fill in project-specific context

Before assigning real work, edit:

- `CLAUDE.md`
- `AGENTS.md`

Add your project’s:

- overview
- tech stack
- route table or module map
- validation checklist
- key constraints and safety rules

## 6. Common install options

```bash
bash install.sh --help
bash install.sh --upgrade
bash install.sh --force
```

- `--upgrade`: update protocol files while preserving entry files such as `CLAUDE.md` and `AGENTS.md`
- `--force`: overwrite files without creating backups

## 7. Local smoke test for maintainers

If you are validating the repository itself:

```bash
bash -n install.sh templates/scripts/*.sh templates/scripts/hooks/* templates/claude-plugin/scripts/*.sh
tmp_dir=$(mktemp -d)
bash install.sh "$tmp_dir"
(
  cd "$tmp_dir"
  ./scripts/field-arrive.sh
  ./scripts/field-pulse.sh
  sqlite3 .termite.db "select id,status,title from signals;"
)
rm -rf "$tmp_dir"
```

## 8. Troubleshooting

### `field-arrive.sh` fails immediately

Check:

- shell is `bash`
- scripts are executable
- the target directory is writable
- your machine has the basic tools used by the scripts

### `.birth` was not created

Run:

```bash
./scripts/field-arrive.sh
ls -la .birth*
```

If genesis did not run, inspect whether the directory already contains old protocol state.

### No initial signal appeared

Check:

```bash
./scripts/field-pulse.sh
sqlite3 .termite.db "select id,status,title from signals;"
cat BLACKBOARD.md
```

If the project already had state, arrival may have reused it instead of bootstrapping a new colony. On a fresh repo, the initial signal is stored in SQLite even when `signals/active/` has no YAML snapshot yet.

## 9. Next steps

- Read `README.md:1` for positioning, use cases, and proof.
- Read `CONTRIBUTING.md:1` if you plan to contribute.
- Read `SUPPORT.md:1` for questions and bug-report routing.
- Read `SECURITY.md:1` for vulnerability reporting.

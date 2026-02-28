#!/usr/bin/env bash
# field-export-audit.sh — Export audit package for protocol-level review
#
# Produces a self-contained directory of protocol artifacts, stripped of all
# project source code. A Protocol Nurse agent can read ONLY this package
# (plus the protocol definition) to evaluate and optimize the protocol itself.
#
# Usage:
#   ./field-export-audit.sh                           # export to ./audit-package-YYYY-MM-DD/
#   ./field-export-audit.sh --out /path/to/target     # export to specific directory
#   ./field-export-audit.sh --tar                      # also create .tar.gz archive
#   ./field-export-audit.sh --project-name "MyApp"     # override auto-detected project name
#
# What's included (protocol artifacts only):
#   signals/          — rules, observations, active signals, archive
#   git-signatures.txt — termite commit signatures (no code diffs)
#   pheromone-chain.jsonl — .pheromone history from git (one JSON per line)
#   immune-log.txt    — immune log section from BLACKBOARD.md
#   breath-snapshot.yaml — current .field-breath
#   caste-distribution.yaml — agent type breakdown from git history
#   rule-health.yaml  — per-rule hit_count vs disputed_count summary
#   metadata.yaml     — project name, protocol version, run duration, totals
#
# What's NOT included:
#   No project source code. No business logic. No .env files. No node_modules.
#   No BLACKBOARD business sections. No DECISIONS.md business content.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${SCRIPT_DIR}/field-lib.sh"

# ── Argument Parsing ─────────────────────────────────────────────────

OUT_DIR=""
CREATE_TAR=false
PROJECT_NAME=""

while [ $# -gt 0 ]; do
  case "$1" in
    --out)           OUT_DIR="$2"; shift 2 ;;
    --tar)           CREATE_TAR=true; shift ;;
    --project-name)  PROJECT_NAME="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--out <dir>] [--tar] [--project-name <name>]"
      echo ""
      echo "Exports a protocol audit package (no project source code)."
      echo "Output: ./audit-package-YYYY-MM-DD/ (or --out path)"
      exit 0
      ;;
    *)
      log_error "Unknown argument: $1"
      exit 1
      ;;
  esac
done

# Default output directory
if [ -z "$OUT_DIR" ]; then
  OUT_DIR="${PROJECT_ROOT}/audit-package-$(today_iso)"
fi

# Auto-detect project name from directory
if [ -z "$PROJECT_NAME" ]; then
  PROJECT_NAME=$(basename "$PROJECT_ROOT")
fi

log_info "=== Audit package export starting ==="
log_info "Project: ${PROJECT_NAME}"
log_info "Output:  ${OUT_DIR}"

# ── Setup Output ─────────────────────────────────────────────────────

mkdir -p "$OUT_DIR"

# ── 1. Signals Directory (complete copy) ─────────────────────────────

log_info "Step 1/7: Copying signals directory"

if has_db; then
  source "${SCRIPT_DIR}/termite-db.sh"
  source "${SCRIPT_DIR}/termite-db-export.sh" --out "${OUT_DIR}" 2>/dev/null || {
    # Direct export if sourcing doesn't work
    db_export_signals_dir "${OUT_DIR}/signals/active"
    db_export_obs_dir "${OUT_DIR}/signals/observations"
    db_export_rules_dir "${OUT_DIR}/signals/rules"
  }
  mkdir -p "${OUT_DIR}/signals/archive"
  rule_count=$(db_exec "SELECT COUNT(*) FROM rules;" 2>/dev/null || echo "0")
  obs_count=$(db_obs_count 2>/dev/null || echo "0")
  active_count=$(db_signal_count "status NOT IN ('archived')" 2>/dev/null || echo "0")
  archive_count=$(db_exec "SELECT COUNT(*) FROM archive;" 2>/dev/null || echo "0")
  log_info "  rules: ${rule_count}, observations: ${obs_count}, active: ${active_count}, archived: ${archive_count} (from DB)"
elif [ -d "$SIGNALS_DIR" ]; then
  # Copy entire signals tree, preserving structure
  cp -R "$SIGNALS_DIR" "${OUT_DIR}/signals"

  # Remove any claim locks (ephemeral, not useful for audit)
  rm -rf "${OUT_DIR}/signals/claims" 2>/dev/null || true

  # Count what we got
  rule_count=$(find "${OUT_DIR}/signals/rules" -name '*.yaml' 2>/dev/null | wc -l | tr -d ' ')
  obs_count=$(find "${OUT_DIR}/signals/observations" -name '*.yaml' 2>/dev/null | wc -l | tr -d ' ')
  active_count=$(find "${OUT_DIR}/signals/active" -name '*.yaml' 2>/dev/null | wc -l | tr -d ' ')
  archive_count=$(find "${OUT_DIR}/signals/archive" -name '*.yaml' 2>/dev/null | wc -l | tr -d ' ')

  log_info "  rules: ${rule_count}, observations: ${obs_count}, active: ${active_count}, archived: ${archive_count}"
else
  mkdir -p "${OUT_DIR}/signals"
  rule_count=0; obs_count=0; active_count=0; archive_count=0
  log_warn "  No signals directory found"
fi

# ── 2. Git Signatures (no code diffs) ────────────────────────────────

log_info "Step 2/7: Extracting git signatures"

sig_file="${OUT_DIR}/git-signatures.txt"

if git -C "$PROJECT_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  # Extract all termite-signed commits: hash, date, caste tag, subject
  # Format: <short-hash> <date> <subject-with-signature>
  git -C "$PROJECT_ROOT" log --all --format="%h %ai %s" --grep='\[termite:' \
    > "$sig_file" 2>/dev/null || true

  total_commits=$(git -C "$PROJECT_ROOT" log --all --oneline 2>/dev/null | wc -l | tr -d ' ')
  signed_commits=$(wc -l < "$sig_file" | tr -d ' ')

  # Also extract unsigned commits (just hash + date + subject, no code)
  echo "" >> "$sig_file"
  echo "# --- Unsigned commits (for IC-3 foreign body analysis) ---" >> "$sig_file"
  git -C "$PROJECT_ROOT" log --all --format="%h %ai %s" 2>/dev/null \
    | grep -v '\[termite:' >> "$sig_file" 2>/dev/null || true

  log_info "  ${signed_commits}/${total_commits} commits signed"
else
  echo "# No git repository found" > "$sig_file"
  total_commits=0; signed_commits=0
  log_warn "  No git repository"
fi

# ── 3. Pheromone Chain (from git history) ─────────────────────────────

log_info "Step 3/7: Extracting pheromone chain"

chain_file="${OUT_DIR}/pheromone-chain.jsonl"
> "$chain_file"

if has_db; then
  chain_count=0
  db_pheromone_chain | while IFS=$'\t' read -r agent_id timestamp caste branch commit_hash completed unresolved pred_useful wip_status active_sig_count; do
    [ -z "$agent_id" ] && continue
    pred_json="null"
    case "$pred_useful" in
      1) pred_json="true" ;;
      0) pred_json="false" ;;
    esac
    echo "{\"timestamp\":\"${timestamp}\",\"caste\":\"${caste}\",\"branch\":\"${branch}\",\"commit\":\"${commit_hash}\",\"completed\":\"${completed}\",\"unresolved\":\"${unresolved}\",\"predecessor_useful\":${pred_json},\"agent_id\":\"${agent_id}\"}" >> "$chain_file"
    chain_count=$((chain_count + 1))
  done
  log_info "  ${chain_count} pheromone snapshots from DB"
elif git -C "$PROJECT_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  # Find all commits that touched .pheromone, extract the file content at each
  pheromone_commits=$(git -C "$PROJECT_ROOT" log --all --follow --format="%H" -- ".pheromone" 2>/dev/null || true)
  chain_count=0

  for commit_hash in $pheromone_commits; do
    # Extract .pheromone content at this commit
    content=$(git -C "$PROJECT_ROOT" show "${commit_hash}:.pheromone" 2>/dev/null || true)
    if [ -n "$content" ]; then
      # Output as single-line JSON (one per line = JSONL)
      echo "$content" | tr '\n' ' ' | sed 's/[[:space:]]*$//' >> "$chain_file"
      echo "" >> "$chain_file"
      chain_count=$((chain_count + 1))
    fi
  done

  # Also include current .pheromone if it exists and isn't committed
  if [ -f "$PHEROMONE_FILE" ]; then
    current_content=$(cat "$PHEROMONE_FILE" | tr '\n' ' ' | sed 's/[[:space:]]*$//')
    # Check if it's already the last entry (avoid duplicate)
    last_entry=$(tail -1 "$chain_file" 2>/dev/null | sed 's/[[:space:]]*$//')
    if [ "$current_content" != "$last_entry" ] && [ -n "$current_content" ]; then
      echo "$current_content" >> "$chain_file"
      chain_count=$((chain_count + 1))
    fi
  fi

  # Remove empty lines
  sed -i.bak '/^[[:space:]]*$/d' "$chain_file" 2>/dev/null || true
  rm -f "${chain_file}.bak"

  log_info "  ${chain_count} pheromone snapshots extracted"
else
  echo '{"error": "no git repository"}' > "$chain_file"
  chain_count=0
fi

# ── 4. Immune Log (from BLACKBOARD, stripped of business content) ─────

log_info "Step 4/7: Extracting immune log"

immune_file="${OUT_DIR}/immune-log.txt"
> "$immune_file"

if [ -f "$BLACKBOARD" ]; then
  # Extract the immune log section: from "## 免疫日志" to the next ## heading
  awk '/^## 免疫日志/,/^## [^免]/' "$BLACKBOARD" 2>/dev/null \
    | sed '$d' >> "$immune_file" || true

  # If empty, try English heading
  if [ ! -s "$immune_file" ]; then
    awk '/^## Immune Log/,/^## /' "$BLACKBOARD" 2>/dev/null \
      | sed '$d' >> "$immune_file" || true
  fi

  if [ -s "$immune_file" ]; then
    immune_entries=$(grep -c '|' "$immune_file" 2>/dev/null || echo "0")
    log_info "  ${immune_entries} immune log entries"
  else
    echo "(no immune log section found in BLACKBOARD.md)" > "$immune_file"
    log_info "  No immune log section found"
  fi

  # Also extract the health status section (protocol-relevant, not business)
  health_file="${OUT_DIR}/blackboard-health.txt"
  awk '/^## 蚁丘健康状态/,/^## /' "$BLACKBOARD" 2>/dev/null \
    | sed '$d' > "$health_file" || true
  if [ ! -s "$health_file" ]; then
    awk '/^## Colony Health/,/^## /' "$BLACKBOARD" 2>/dev/null \
      | sed '$d' > "$health_file" || true
  fi
  [ ! -s "$health_file" ] && echo "(no health section found)" > "$health_file"
else
  echo "(no BLACKBOARD.md found)" > "$immune_file"
  log_warn "  No BLACKBOARD.md"
fi

# ── 5. Breath Snapshot ───────────────────────────────────────────────

log_info "Step 5/7: Copying breath snapshot"

if [ -f "$BREATH_FILE" ]; then
  cp "$BREATH_FILE" "${OUT_DIR}/breath-snapshot.yaml"
  log_info "  Copied current .field-breath"
else
  cat > "${OUT_DIR}/breath-snapshot.yaml" <<EOF
# No .field-breath found at export time
alarm: unknown
wip: unknown
build: unknown
signature_ratio: 0.00
active_signals: 0
high_weight_holes: 0
branch: unknown
EOF
  log_info "  No .field-breath found, created placeholder"
fi

# ── 6. Derived Metrics ──────────────────────────────────────────────

log_info "Step 6/7: Computing derived metrics"

# 6a. Caste distribution from git signatures
caste_file="${OUT_DIR}/caste-distribution.yaml"
cat > "$caste_file" <<EOF
# Caste distribution from git commit signatures
# Extracted from: ${PROJECT_NAME}
# Date: $(today_iso)
EOF

if [ -s "$sig_file" ] && [ "$signed_commits" -gt 0 ]; then
  # Parse [termite:DATE:CASTE] patterns and count castes
  echo "distribution:" >> "$caste_file"
  grep -oE '\[termite:[0-9-]+:[a-z-]+\]' "$sig_file" 2>/dev/null \
    | sed 's/.*:\([a-z-]*\)\]/\1/' \
    | sort | uniq -c | sort -rn \
    | while read -r count caste; do
      echo "  ${caste}: ${count}" >> "$caste_file"
    done

  # Time range
  first_sig=$(grep -oE '\[termite:[0-9-]+:' "$sig_file" 2>/dev/null | head -1 | sed 's/\[termite://;s/:$//')
  last_sig=$(grep -oE '\[termite:[0-9-]+:' "$sig_file" 2>/dev/null | tail -1 | sed 's/\[termite://;s/:$//')
  echo "first_signature: ${last_sig:-unknown}" >> "$caste_file"
  echo "last_signature: ${first_sig:-unknown}" >> "$caste_file"
else
  echo "distribution: {}" >> "$caste_file"
  echo "first_signature: none" >> "$caste_file"
  echo "last_signature: none" >> "$caste_file"
fi

log_info "  Caste distribution computed"

# 6b. Rule health summary (hit vs disputed)
rule_health_file="${OUT_DIR}/rule-health.yaml"
cat > "$rule_health_file" <<EOF
# Rule health: hit_count vs disputed_count
# disputed_ratio > 0.3 flags a rule for review
# Extracted from: ${PROJECT_NAME}
# Date: $(today_iso)
rules:
EOF

if [ -d "${OUT_DIR}/signals/rules" ]; then
  for rf in "${OUT_DIR}/signals/rules"/*.yaml; do
    [ -f "$rf" ] || continue
    rid=$(yaml_read "$rf" "id")
    hits=$(yaml_read "$rf" "hit_count")
    disputed=$(yaml_read "$rf" "disputed_count")
    trigger=$(yaml_read "$rf" "trigger")
    hits="${hits:-0}"
    disputed="${disputed:-0}"

    # Compute ratio (avoid division by zero)
    if [ "$hits" -gt 0 ]; then
      ratio=$(awk "BEGIN { printf \"%.2f\", ${disputed}/${hits} }")
    else
      ratio="0.00"
    fi

    # Flag if ratio > 0.3
    flag=""
    if [ "${hits:-0}" -gt 0 ]; then
      needs_review=$(awk "BEGIN { print (${disputed}/${hits} > 0.3) ? \"true\" : \"false\" }")
    else
      needs_review="false"
    fi
    if [ "$needs_review" = "true" ] && [ "$hits" -gt 0 ]; then
      flag="  # REVIEW NEEDED"
    fi

    cat >> "$rule_health_file" <<EOF
  - id: ${rid}
    trigger: "${trigger}"
    hit_count: ${hits}
    disputed_count: ${disputed}
    disputed_ratio: ${ratio}${flag}
EOF
  done
fi

log_info "  Rule health summary computed"

# 6c. Pheromone chain quality (predecessor_useful stats)
handoff_file="${OUT_DIR}/handoff-quality.yaml"
cat > "$handoff_file" <<EOF
# Cross-session handoff quality from pheromone chain
# predecessor_useful: true/false/null evaluation chain
# Extracted from: ${PROJECT_NAME}
# Date: $(today_iso)
EOF

if [ -s "$chain_file" ]; then
  total_handoffs=$(wc -l < "$chain_file" | tr -d ' ')
  useful_count=$(grep -c '"predecessor_useful"[[:space:]]*:[[:space:]]*true' "$chain_file" 2>/dev/null || echo "0")
  not_useful_count=$(grep -c '"predecessor_useful"[[:space:]]*:[[:space:]]*false' "$chain_file" 2>/dev/null || echo "0")
  not_evaluated=$((total_handoffs - useful_count - not_useful_count))

  cat >> "$handoff_file" <<EOF
total_handoffs: ${total_handoffs}
predecessor_useful_true: ${useful_count}
predecessor_useful_false: ${not_useful_count}
predecessor_useful_not_evaluated: ${not_evaluated}
EOF

  if [ "$((useful_count + not_useful_count))" -gt 0 ]; then
    useful_ratio=$(awk "BEGIN { printf \"%.2f\", ${useful_count}/(${useful_count}+${not_useful_count}) }")
    echo "useful_ratio: ${useful_ratio}" >> "$handoff_file"
  else
    echo "useful_ratio: null  # no evaluations yet" >> "$handoff_file"
  fi
else
  cat >> "$handoff_file" <<EOF
total_handoffs: 0
predecessor_useful_true: 0
predecessor_useful_false: 0
predecessor_useful_not_evaluated: 0
useful_ratio: null
EOF
fi

log_info "  Handoff quality stats computed"

# ── 7. Metadata ──────────────────────────────────────────────────────

log_info "Step 7/7: Writing metadata"

# Detect protocol version from TERMITE_PROTOCOL.md
protocol_version="unknown"
if [ -f "${PROJECT_ROOT}/TERMITE_PROTOCOL.md" ]; then
  protocol_version=$(grep -m1 'termite-protocol:v' "${PROJECT_ROOT}/TERMITE_PROTOCOL.md" 2>/dev/null \
    | sed 's/.*termite-protocol:\(v[0-9.]*\).*/\1/' || echo "unknown")
fi

# Detect kernel version from entry file
kernel_version="unknown"
for entry_file in "${PROJECT_ROOT}/CLAUDE.md" "${PROJECT_ROOT}/AGENTS.md"; do
  if [ -f "$entry_file" ]; then
    kv=$(grep -m1 'termite-kernel:v' "$entry_file" 2>/dev/null \
      | sed 's/.*termite-kernel:\(v[0-9.]*\).*/\1/' || true)
    if [ -n "$kv" ]; then
      kernel_version="$kv"
      break
    fi
  fi
done

# Compute protocol run duration (first signed commit to now)
run_days=0
if [ -n "${last_sig:-}" ] && [ "$last_sig" != "unknown" ] && [ "$last_sig" != "none" ]; then
  run_days=$(days_since "$last_sig")
fi

# Signature ratio
sig_ratio=$(termite_signature_ratio 50)

cat > "${OUT_DIR}/metadata.yaml" <<EOF
# Audit Package Metadata
# This file describes the context of the export.
# Protocol Nurse: read this first to understand the project context.

project_name: "${PROJECT_NAME}"
export_date: "$(now_iso)"
protocol_version: "${protocol_version}"
kernel_version: "${kernel_version}"

# Duration & Volume
run_duration_days: ${run_days}
total_commits: ${total_commits}
signed_commits: ${signed_commits}
signature_ratio_last_50: ${sig_ratio}

# Signal Inventory
active_signals: ${active_count}
pending_observations: ${obs_count}
active_rules: ${rule_count}
archived_items: ${archive_count}
pheromone_snapshots: ${chain_count}

# Current State
current_branch: "$(current_branch)"
current_alarm: $([ -f "$ALARM_FILE" ] && echo "true" || echo "false")
current_wip: "$(check_wip)"
current_build: "$(check_build)"
EOF

log_info "  Metadata written"

# ── Package Summary ──────────────────────────────────────────────────

# Write a README for the package
cat > "${OUT_DIR}/README.md" <<'READMEEOF'
# Audit Package

This directory contains protocol-level artifacts exported from a project
running the Termite Protocol. It contains **no project source code**.

A Protocol Nurse agent can read this package + the protocol definition
to evaluate protocol health and produce optimization recommendations.

## Contents

| File | What it tells you |
|------|-------------------|
| `metadata.yaml` | Project context, duration, volume (read first) |
| `signals/` | Complete signal tree: rules, observations, active, archive |
| `rule-health.yaml` | Per-rule hit vs disputed ratio (flags problematic rules) |
| `handoff-quality.yaml` | predecessor_useful stats (cross-session handoff effectiveness) |
| `caste-distribution.yaml` | Which castes appeared and how often |
| `git-signatures.txt` | Commit timeline with termite signatures (no code) |
| `pheromone-chain.jsonl` | .pheromone history (one JSON per line, chronological) |
| `immune-log.txt` | Immune system findings from BLACKBOARD |
| `blackboard-health.txt` | Colony health status table |
| `breath-snapshot.yaml` | Latest .field-breath health snapshot |

## How to Use

```
# Copy this directory to the protocol repo:
cp -R audit-package-YYYY-MM-DD /path/to/termite-protocol/audit-packages/project-name/

# Or analyze in place:
# A Protocol Nurse agent reads metadata.yaml first, then rule-health.yaml
# and handoff-quality.yaml for quick protocol health assessment.
```
READMEEOF

# ── Optional: tar.gz ─────────────────────────────────────────────────

if [ "$CREATE_TAR" = true ]; then
  tar_name="$(basename "$OUT_DIR").tar.gz"
  tar_path="$(dirname "$OUT_DIR")/${tar_name}"
  tar -czf "$tar_path" -C "$(dirname "$OUT_DIR")" "$(basename "$OUT_DIR")"
  log_info "Archive created: ${tar_path}"
fi

# ── Done ─────────────────────────────────────────────────────────────

log_info "=== Audit package exported to: ${OUT_DIR} ==="
log_info "Contents:"
log_info "  metadata.yaml            — project context (read first)"
log_info "  signals/                 — ${rule_count} rules, ${obs_count} observations, ${active_count} active, ${archive_count} archived"
log_info "  rule-health.yaml         — hit vs disputed per rule"
log_info "  handoff-quality.yaml     — predecessor_useful chain stats"
log_info "  caste-distribution.yaml  — agent caste breakdown"
log_info "  git-signatures.txt       — ${signed_commits}/${total_commits} signed commits"
log_info "  pheromone-chain.jsonl    — ${chain_count} handoff snapshots"
log_info "  immune-log.txt           — immune system findings"
log_info "  breath-snapshot.yaml     — current health"
echo ""
echo "${OUT_DIR}"

#!/usr/bin/env bash
# find-knowledge.sh — query discovery knowledge cards by ID or keywords

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CARDS_DIR="${ROOT_DIR}/docs/knowledge-base/cards"
INDEX_FILE="${ROOT_DIR}/docs/knowledge-base/INDEX.md"

usage() {
  cat <<'EOF'
Usage:
  ./audit-analysis/scripts/find-knowledge.sh <KB_ID|KEYWORDS>

Examples:
  ./audit-analysis/scripts/find-knowledge.sh KB-001
  ./audit-analysis/scripts/find-knowledge.sh "noise filtering"
  ./audit-analysis/scripts/find-knowledge.sh "W-013 quality regression"
EOF
}

extract_frontmatter_field() {
  local file="$1" key="$2"
  awk -v key="$key" '
    BEGIN {in_fm=0}
    /^---[[:space:]]*$/ {
      if (in_fm == 0) { in_fm=1; next }
      exit
    }
    in_fm == 1 && $0 ~ ("^" key ":[[:space:]]*") {
      sub("^" key ":[[:space:]]*", "", $0)
      gsub(/^"/, "", $0)
      gsub(/"$/, "", $0)
      print
      exit
    }
  ' "$file"
}

print_card() {
  local file="$1"
  local id title status summary tags
  id="$(extract_frontmatter_field "$file" "id")"
  title="$(extract_frontmatter_field "$file" "title")"
  status="$(extract_frontmatter_field "$file" "status")"
  summary="$(extract_frontmatter_field "$file" "summary")"
  tags="$(extract_frontmatter_field "$file" "tags")"

  printf '%s | %s\n' "${id:-UNKNOWN}" "${title:-No title}"
  if [ -n "${status}" ]; then
    printf '  status: %s\n' "${status}"
  fi
  if [ -n "${summary}" ]; then
    printf '  summary: %s\n' "${summary}"
  fi
  if [ -n "${tags}" ]; then
    printf '  tags: %s\n' "${tags}"
  fi
  printf '  card: %s\n' "${file}"
}

if [ ! -d "$CARDS_DIR" ]; then
  echo "Knowledge cards directory not found: $CARDS_DIR" >&2
  exit 1
fi

if [ "${1:-}" = "" ]; then
  usage
  echo
  if [ -f "$INDEX_FILE" ]; then
    echo "Tip: browse index -> $INDEX_FILE"
  fi
  exit 1
fi

query="$*"
matches=""

if [[ "$query" =~ ^KB-[0-9]{3}$ ]]; then
  matches="$(rg -l --glob '*.md' "^id:[[:space:]]*${query}[[:space:]]*$" "$CARDS_DIR" || true)"
else
  matches="$(rg -l -i --glob '*.md' -- "$query" "$CARDS_DIR" || true)"
  if [ -z "$matches" ] && [[ "$query" == *" "* ]]; then
    # Fallback #1: multi-keyword AND match.
    lookahead=""
    for term in $query; do
      escaped="$(printf '%s' "$term" | sed 's/[.[\*^$()+?{}|\\]/\\&/g')"
      lookahead="${lookahead}(?=.*${escaped})"
    done
    matches="$(rg -l -i -P --glob '*.md' -- "${lookahead}.*" "$CARDS_DIR" || true)"
  fi
  if [ -z "$matches" ] && [[ "$query" == *" "* ]]; then
    # Fallback #2: multi-keyword OR match to improve recall in audit triage.
    or_regex=""
    for term in $query; do
      escaped="$(printf '%s' "$term" | sed 's/[.[\*^$()+?{}|\\]/\\&/g')"
      if [ -z "$or_regex" ]; then
        or_regex="${escaped}"
      else
        or_regex="${or_regex}|${escaped}"
      fi
    done
    matches="$(rg -l -i -P --glob '*.md' -- "(${or_regex})" "$CARDS_DIR" || true)"
  fi
fi

if [ -z "$matches" ]; then
  echo "No knowledge cards found for query: $query"
  if [ -f "$INDEX_FILE" ]; then
    echo "Browse full index: $INDEX_FILE"
  fi
  exit 2
fi

echo "Knowledge cards for query: $query"
echo
while IFS= read -r file; do
  [ -z "$file" ] && continue
  print_card "$file"
  echo
done <<< "$matches"

echo "Open the card file for activation gates and experiment guidance."

#!/usr/bin/env python3
"""
H2 Validation: Run quality_score heuristic against A-006 touchcli 270 observations.

Implements the quality_score from v5.0 design doc:
  base = 0.5
  +0.15  detail > 80 chars and contains paths/numbers/metrics
  +0.15  pattern references specific files, modules, or error messages
  +0.10  context non-empty and doesn't duplicate pattern
  +0.10  detail contains comparison/causation/recommendation signals
  -0.30  pattern is signal-ID-only, heartbeat, or phase keyword
  -0.30  detail is pure number, empty, or < 10 chars
  -0.20  pattern >80% keyword overlap with recent observations (simplified: is a screaming label)
  clamp(0.0, 1.0)

Compares against audit report's manual assessment: 116/270 = 43% degenerate.
"""

import os
import re
import sys
import json
from pathlib import Path

OBS_DIR = Path(__file__).parent.parent / "audit-packages/touchcli/2026-03-03/signals/observations"


def parse_observation(filepath):
    """Simple YAML parser for observation files."""
    data = {}
    current_key = None
    multiline_buf = []

    with open(filepath, 'r') as f:
        for line in f:
            # Skip comments
            if line.startswith('#'):
                continue
            # Check for new key
            m = re.match(r'^(\w+):\s*(.*)', line)
            if m:
                # Save previous multiline
                if current_key and multiline_buf:
                    data[current_key] = '\n'.join(multiline_buf).strip()
                    multiline_buf = []

                key = m.group(1)
                val = m.group(2).strip()

                if val == '|':
                    current_key = key
                    multiline_buf = []
                else:
                    # Strip quotes
                    if val.startswith('"') and val.endswith('"'):
                        val = val[1:-1]
                    data[key] = val
                    current_key = None
            elif current_key is not None:
                multiline_buf.append(line.rstrip())

    # Flush last multiline
    if current_key and multiline_buf:
        data[current_key] = '\n'.join(multiline_buf).strip()

    return data


def is_screaming_label(s):
    """Check if string is a SCREAMING-CASE label (e.g. HEARTBEAT-PHASE6-START)."""
    # Remove leading S-xxx prefix
    cleaned = re.sub(r'^S-\d+[-_]?', '', s)
    if not cleaned:
        return True  # was just S-xxx
    # Check if remaining is mostly uppercase + hyphens + digits
    alpha_chars = [c for c in cleaned if c.isalpha()]
    if not alpha_chars:
        return True
    upper_ratio = sum(1 for c in alpha_chars if c.isupper()) / len(alpha_chars)
    return upper_ratio > 0.7 and len(s) < 60


def has_file_path(s):
    """Check if string contains file paths."""
    patterns = [
        r'[\w/-]+\.\w{1,4}',          # file.ext
        r'src/\w+',                      # src/...
        r'backend/\w+',                  # backend/...
        r'frontend/\w+',                 # frontend/...
        r'scripts/\w+',                  # scripts/...
        r'[\w]+/[\w]+/[\w]+\.\w+',      # a/b/c.ext
    ]
    for p in patterns:
        if re.search(p, s):
            return True
    return False


def has_metrics(s):
    """Check if string contains specific numbers/metrics."""
    patterns = [
        r'\d+\s*(ms|MB|KB|GB|LOC|%|req|tests?|msgs?/sec)',  # units
        r'p\d{2,3}\s*[=<>]',            # percentiles
        r'\d+/\d+',                      # ratios like 26/26
        r'HTTP\s*\d{3}',                # HTTP status
        r'\d+\s*commit',                 # commit counts
        r'n=\d+',                        # sample sizes
        r'c=\d+',                        # concurrency
    ]
    for p in patterns:
        if re.search(p, s, re.IGNORECASE):
            return True
    return False


def has_causal_signals(s):
    """Check for comparison/causation/recommendation language."""
    signals = [
        r'\bbecause\b', r'\brisk[:\s]', r'\bmissing[:\s]',
        r'\brecommend', r'\bshould\b', r'\bneed[s]?\b',
        r'→', r'=>', r'\bfix', r'\bbug\b', r'\bgap\b',
        r'\bpreviously\b', r'\badded\b.*\bto\b',
        r'\bwithout\b', r'\binstead\b', r'\bhowever\b',
        r'\bnot\s+satisfied', r'\bfailed?\b', r'\berror\b',
        r'\broot\s*cause', r'\bworkaround',
        r'回退', r'风险', r'缺失', r'建议', r'原因',
    ]
    for p in signals:
        if re.search(p, s, re.IGNORECASE):
            return True
    return False


def is_degenerate_pattern(pattern):
    """Check if pattern is a degenerate marker."""
    p = pattern.strip()

    # Pure signal ID: S-007, O-xxx
    if re.match(r'^[SO]-\d+$', p):
        return True

    # Screaming label with no substance
    if is_screaming_label(p):
        return True

    # Contains heartbeat/phase keywords and is short
    if re.search(r'(?i)(heartbeat|HEARTBEAT)', p) and len(p) < 80:
        return True

    return False


def is_degenerate_detail(detail):
    """Check if detail is degenerate."""
    d = detail.strip()
    if not d:
        return True
    if d == '0' or d == '0.0':
        return True
    if re.match(r'^\d+$', d):
        return True
    if len(d) < 10:
        return True
    return False


def compute_quality_score(obs):
    """Compute quality_score for an observation."""
    pattern = obs.get('pattern', '')
    context = obs.get('context', '')
    detail = obs.get('detail', '')

    score = 0.5
    reasons = []

    # --- Positive indicators ---

    # +0.15: detail > 80 chars and contains paths/numbers
    if len(detail) > 80 and (has_file_path(detail) or has_metrics(detail)):
        score += 0.15
        reasons.append('+0.15 detail rich with paths/metrics')

    # +0.15: pattern references specific files/modules/errors
    if has_file_path(pattern) or (re.search(r'[a-z_]+\.[a-z_]+', pattern) and len(pattern) > 30):
        score += 0.15
        reasons.append('+0.15 pattern has specific references')
    elif len(pattern) > 60 and not is_screaming_label(pattern):
        # Long descriptive pattern (natural language)
        score += 0.15
        reasons.append('+0.15 pattern is descriptive')

    # +0.10: context non-empty and not duplicating pattern
    if context and len(context) > 5:
        # Check overlap
        ctx_words = set(context.lower().split())
        pat_words = set(pattern.lower().split())
        if pat_words:
            overlap = len(ctx_words & pat_words) / max(len(pat_words), 1)
        else:
            overlap = 0
        if overlap < 0.8:
            score += 0.10
            reasons.append('+0.10 context adds info')

    # +0.10: detail has causal/recommendation signals
    if has_causal_signals(detail) or has_causal_signals(pattern):
        score += 0.10
        reasons.append('+0.10 causal/recommendation language')

    # --- Negative indicators ---

    # -0.30: pattern is degenerate
    if is_degenerate_pattern(pattern):
        score -= 0.30
        reasons.append('-0.30 degenerate pattern')

    # -0.30: detail is degenerate
    if is_degenerate_detail(detail):
        score -= 0.30
        reasons.append('-0.30 degenerate detail')

    # -0.20: screaming label (proxy for keyword overlap / low substance)
    if is_screaming_label(pattern) and not has_file_path(context):
        score -= 0.20
        reasons.append('-0.20 screaming label, no file context')

    # Clamp
    score = max(0.0, min(1.0, score))

    return round(score, 2), reasons


def main():
    files = sorted(OBS_DIR.glob('O-*.yaml'))
    print(f"Scanning {len(files)} observations...\n")

    results = []
    for f in files:
        obs = parse_observation(f)
        score, reasons = compute_quality_score(obs)
        results.append({
            'id': obs.get('id', f.stem),
            'score': score,
            'pattern': obs.get('pattern', '')[:80],
            'detail_len': len(obs.get('detail', '')),
            'confidence': obs.get('confidence', ''),
            'reasons': reasons,
        })

    # Sort by score
    results.sort(key=lambda x: x['score'])

    # --- Distribution ---
    scores = [r['score'] for r in results]
    high = [s for s in scores if s >= 0.7]
    mid = [s for s in scores if 0.4 <= s < 0.7]
    low = [s for s in scores if s < 0.4]

    print("=" * 80)
    print("QUALITY SCORE DISTRIBUTION")
    print("=" * 80)
    print(f"Total observations:  {len(scores)}")
    print(f"High (>= 0.7):      {len(high):3d} ({100*len(high)/len(scores):.1f}%)")
    print(f"Medium (0.4-0.69):   {len(mid):3d} ({100*len(mid)/len(scores):.1f}%)")
    print(f"Low (< 0.4):         {len(low):3d} ({100*len(low)/len(scores):.1f}%)")
    print(f"Mean score:          {sum(scores)/len(scores):.3f}")
    print(f"Median score:        {sorted(scores)[len(scores)//2]:.3f}")
    print()

    # --- Histogram ---
    print("HISTOGRAM (bucket width 0.1)")
    print("-" * 50)
    for bucket_start in [i/10 for i in range(0, 10)]:
        bucket_end = bucket_start + 0.1
        count = sum(1 for s in scores if bucket_start <= s < bucket_end)
        bar = '#' * count
        print(f"  [{bucket_start:.1f}-{bucket_end:.1f}): {count:3d} {bar}")
    count_10 = sum(1 for s in scores if s >= 1.0)
    if count_10:
        print(f"  [1.0]:       {count_10:3d} {'#' * count_10}")
    print()

    # --- Comparison with audit report ---
    print("=" * 80)
    print("COMPARISON WITH AUDIT REPORT")
    print("=" * 80)
    print(f"Audit report: 116/270 = 43.0% degenerate (manual assessment)")
    print(f"quality_score < 0.4: {len(low)}/270 = {100*len(low)/len(scores):.1f}%")
    print(f"quality_score < 0.3: {sum(1 for s in scores if s < 0.3)}/270 = {100*sum(1 for s in scores if s < 0.3)/len(scores):.1f}%")
    print(f"quality_score < 0.5: {sum(1 for s in scores if s < 0.5)}/270 = {100*sum(1 for s in scores if s < 0.5)/len(scores):.1f}%")
    print()

    # --- Emergence simulation ---
    print("=" * 80)
    print("EMERGENCE SIMULATION")
    print("=" * 80)

    # Group observations by simplified pattern keywords
    from collections import Counter, defaultdict
    keyword_groups = defaultdict(list)
    for r in results:
        # Extract keywords from pattern (lowercase, strip signal IDs)
        pat = re.sub(r'[SO]-\d+[-_]?\s*', '', r['pattern'].lower())
        # Remove short words and punctuation
        words = re.findall(r'[a-z]{3,}', pat)
        key = ' '.join(sorted(set(words[:5])))  # Top 5 keywords as group key
        if key:
            keyword_groups[key].append(r)

    # Find groups that would trigger emergence under old vs new rules
    print(f"\nOld Rule 7 (count >= 3): groups that trigger")
    old_triggers = 0
    for key, group in sorted(keyword_groups.items(), key=lambda x: -len(x[1])):
        if len(group) >= 3:
            avg_score = sum(r['score'] for r in group) / len(group)
            total_score = sum(r['score'] for r in group)
            print(f"  [{len(group)} obs, avg={avg_score:.2f}, sum={total_score:.2f}] {key[:60]}")
            old_triggers += 1
    print(f"  Total old triggers: {old_triggers}")

    print(f"\nNew Rule 7 (sum(quality) >= 3.0): groups that trigger")
    new_triggers = 0
    for key, group in sorted(keyword_groups.items(), key=lambda x: -sum(r['score'] for r in x[1])):
        total_score = sum(r['score'] for r in group)
        if total_score >= 3.0:
            avg_score = total_score / len(group)
            print(f"  [{len(group)} obs, avg={avg_score:.2f}, sum={total_score:.2f}] {key[:60]}")
            new_triggers += 1
    print(f"  Total new triggers: {new_triggers}")
    print()

    # --- Bottom 20 (worst) ---
    print("=" * 80)
    print("BOTTOM 20 (lowest quality_score)")
    print("=" * 80)
    for r in results[:20]:
        print(f"  {r['score']:.2f}  {r['id']}  detail_len={r['detail_len']:3d}  pattern: {r['pattern'][:65]}")
        if r['reasons']:
            print(f"        reasons: {', '.join(r['reasons'])}")
    print()

    # --- Top 20 (best) ---
    print("=" * 80)
    print("TOP 20 (highest quality_score)")
    print("=" * 80)
    for r in results[-20:]:
        print(f"  {r['score']:.2f}  {r['id']}  detail_len={r['detail_len']:3d}  pattern: {r['pattern'][:65]}")
        if r['reasons']:
            print(f"        reasons: {', '.join(r['reasons'])}")
    print()

    # --- Edge cases worth examining ---
    print("=" * 80)
    print("INTERESTING EDGE CASES (score 0.4-0.6)")
    print("=" * 80)
    edge = [r for r in results if 0.4 <= r['score'] <= 0.6]
    for r in edge[:15]:
        print(f"  {r['score']:.2f}  {r['id']}  detail_len={r['detail_len']:3d}  pattern: {r['pattern'][:65]}")
        if r['reasons']:
            print(f"        reasons: {', '.join(r['reasons'])}")

    # Write full results to JSON for further analysis
    output_path = Path(__file__).parent / "h2-quality-score-results.json"
    with open(output_path, 'w') as f:
        json.dump(results, f, indent=2, ensure_ascii=False)
    print(f"\nFull results written to: {output_path}")


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""Summarize audit-package readiness for protocol experiments."""

from __future__ import annotations

import argparse
import json
import re
from collections import Counter
from pathlib import Path
from typing import Any

import yaml


ROOT_DIR = Path(__file__).resolve().parents[2]
AUDIT_PACKAGES_DIR = ROOT_DIR / "audit-packages"
ID_ONLY_PATTERN = re.compile(r"^[SO]-\d+(?:\s+[SO]-\d+)*$")


def load_yaml(path: Path) -> Any:
    try:
        return yaml.safe_load(path.read_text()) or {}
    except Exception:
        return {}


def ratio(numerator: int, denominator: int) -> float | None:
    if denominator == 0:
        return None
    return round(numerator / denominator, 3)


def is_nonempty(value: Any) -> bool:
    return value not in (None, "", "[]", [], {})


def is_numeric(value: Any) -> bool:
    if isinstance(value, (int, float)):
        return True
    if isinstance(value, str):
        try:
            float(value)
            return True
        except ValueError:
            return False
    return False


def summarize_observations(observation_dir: Path) -> dict[str, Any]:
    observation_files = sorted(observation_dir.glob("*.yaml")) if observation_dir.exists() else []
    confidence_present = 0
    source_type_present = 0
    numeric_quality = 0
    short_detail = 0
    id_only_pattern = 0
    quality_literals: Counter[str] = Counter()

    for observation_file in observation_files:
        observation = load_yaml(observation_file)
        if is_nonempty(observation.get("confidence")):
            confidence_present += 1
        if is_nonempty(observation.get("source_type")):
            source_type_present += 1

        quality_score = observation.get("quality_score")
        if quality_score is not None:
            if is_numeric(quality_score):
                numeric_quality += 1
            else:
                quality_literals[str(quality_score)] += 1

        detail = str(observation.get("detail", "")).strip()
        if detail in ("", "0", "0.0") or len(detail) < 10:
            short_detail += 1

        pattern = str(observation.get("pattern", "")).strip()
        if ID_ONLY_PATTERN.match(pattern):
            id_only_pattern += 1

    return {
        "count": len(observation_files),
        "confidence_ratio": ratio(confidence_present, len(observation_files)),
        "source_type_ratio": ratio(source_type_present, len(observation_files)),
        "numeric_quality_ratio": ratio(numeric_quality, len(observation_files)),
        "short_detail_ratio": ratio(short_detail, len(observation_files)),
        "id_only_pattern_ratio": ratio(id_only_pattern, len(observation_files)),
        "quality_literals": dict(quality_literals.most_common(3)),
    }


def summarize_signals(active_dir: Path) -> dict[str, Any]:
    signal_files = sorted(active_dir.glob("S-*.yaml")) if active_dir.exists() else []
    module_present = 0
    status_present = 0
    weight_numeric = 0
    signal_type_present = 0
    status_counts: Counter[str] = Counter()
    module_counts: Counter[str] = Counter()

    for signal_file in signal_files:
        signal = load_yaml(signal_file)

        module = signal.get("module")
        if is_nonempty(module):
            module_present += 1
            module_counts[str(module)] += 1

        status = signal.get("status")
        if is_nonempty(status):
            status_present += 1
            status_counts[str(status)] += 1

        if is_numeric(signal.get("weight")):
            weight_numeric += 1

        if is_nonempty(signal.get("type")):
            signal_type_present += 1

    return {
        "count": len(signal_files),
        "module_ratio": ratio(module_present, len(signal_files)),
        "status_ratio": ratio(status_present, len(signal_files)),
        "weight_ratio": ratio(weight_numeric, len(signal_files)),
        "type_ratio": ratio(signal_type_present, len(signal_files)),
        "status_counts": dict(status_counts),
        "top_modules": dict(module_counts.most_common(5)),
    }


def summarize_rules(rule_health_path: Path) -> dict[str, Any]:
    rule_health = load_yaml(rule_health_path)
    rules = rule_health.get("rules") or []
    labeled_rules = 0
    hit_total = 0
    disputed_total = 0

    for rule in rules:
        hit_count = int(rule.get("hit_count", 0) or 0)
        disputed_count = int(rule.get("disputed_count", 0) or 0)
        hit_total += hit_count
        disputed_total += disputed_count
        if hit_count > 0 or disputed_count > 0:
            labeled_rules += 1

    return {
        "count": len(rules),
        "labeled_count": labeled_rules,
        "hit_total": hit_total,
        "disputed_total": disputed_total,
    }


def summarize_package(package_dir: Path) -> dict[str, Any]:
    metadata = load_yaml(package_dir / "metadata.yaml")
    handoff = load_yaml(package_dir / "handoff-quality.yaml")
    observations = summarize_observations(package_dir / "signals" / "observations")
    signals = summarize_signals(package_dir / "signals" / "active")
    rules = summarize_rules(package_dir / "rule-health.yaml")

    return {
        "package": str(package_dir.relative_to(ROOT_DIR)),
        "project": metadata.get("project_name", package_dir.parent.name),
        "protocol_version": metadata.get("protocol_version", "unknown"),
        "observation_count": observations["count"],
        "signal_files": signals["count"],
        "active_signals_metric": metadata.get("active_signals"),
        "rule_count": rules["count"],
        "labeled_rules": rules["labeled_count"],
        "rule_hits": rules["hit_total"],
        "rule_disputes": rules["disputed_total"],
        "handoffs": handoff.get("total_handoffs"),
        "handoff_useful_ratio": handoff.get("useful_ratio"),
        "module_ratio": signals["module_ratio"],
        "status_ratio": signals["status_ratio"],
        "weight_ratio": signals["weight_ratio"],
        "type_ratio": signals["type_ratio"],
        "signal_status_counts": signals["status_counts"],
        "top_modules": signals["top_modules"],
        "confidence_ratio": observations["confidence_ratio"],
        "source_type_ratio": observations["source_type_ratio"],
        "numeric_quality_ratio": observations["numeric_quality_ratio"],
        "short_detail_ratio": observations["short_detail_ratio"],
        "id_only_pattern_ratio": observations["id_only_pattern_ratio"],
        "quality_literals": observations["quality_literals"],
    }


def iter_packages() -> list[Path]:
    metadata_files = sorted(AUDIT_PACKAGES_DIR.glob("**/metadata.yaml"))
    return [metadata_file.parent for metadata_file in metadata_files]


def aggregate(records: list[dict[str, Any]]) -> dict[str, Any]:
    total_observations = sum(record["observation_count"] for record in records)
    total_signal_files = sum(record["signal_files"] for record in records)
    total_rules = sum(record["rule_count"] for record in records)
    total_labeled_rules = sum(record["labeled_rules"] for record in records)

    packages_with_signal_replay = sum(
        1
        for record in records
        if record["signal_files"] >= 10 and (record["module_ratio"] or 0.0) >= 0.5
    )
    packages_with_numeric_quality = sum(
        1 for record in records if (record["numeric_quality_ratio"] or 0.0) >= 0.9
    )

    return {
        "package_count": len(records),
        "total_observations": total_observations,
        "total_signal_files": total_signal_files,
        "total_rules": total_rules,
        "total_labeled_rules": total_labeled_rules,
        "packages_with_signal_replay_ready": packages_with_signal_replay,
        "packages_with_numeric_quality_ready": packages_with_numeric_quality,
    }


def as_string(value: Any) -> str:
    if value is None:
        return "-"
    if isinstance(value, float):
        return f"{value:.3f}"
    if isinstance(value, dict):
        if not value:
            return "-"
        return ", ".join(f"{key}:{val}" for key, val in value.items())
    return str(value)


def print_markdown(records: list[dict[str, Any]], summary: dict[str, Any]) -> None:
    columns = [
        ("package", "Package"),
        ("protocol_version", "Proto"),
        ("observation_count", "Obs"),
        ("signal_files", "Signals"),
        ("rule_count", "Rules"),
        ("labeled_rules", "Labeled Rules"),
        ("handoffs", "Handoffs"),
        ("module_ratio", "Module Cov"),
        ("numeric_quality_ratio", "Numeric quality"),
        ("short_detail_ratio", "Short detail"),
        ("id_only_pattern_ratio", "ID-only pattern"),
        ("quality_literals", "Quality literals"),
    ]

    header = "| " + " | ".join(title for _, title in columns) + " |"
    divider = "| " + " | ".join("---" for _ in columns) + " |"

    print(header)
    print(divider)
    for record in records:
        row = "| " + " | ".join(as_string(record[key]) for key, _ in columns) + " |"
        print(row)

    print()
    print("Summary:")
    for key, value in summary.items():
        print(f"- {key}: {as_string(value)}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true", help="print JSON instead of markdown")
    args = parser.parse_args()

    records = [summarize_package(package_dir) for package_dir in iter_packages()]
    summary = aggregate(records)

    if args.json:
        print(json.dumps({"records": records, "summary": summary}, ensure_ascii=False, indent=2))
        return

    print_markdown(records, summary)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Validate source data for Frontline Command: Atlas."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
regions_path = ROOT / "data" / "regions.json"
regions = json.loads(regions_path.read_text(encoding="utf-8"))

assert isinstance(regions, list), "regions.json must contain a list"
assert len(regions) == 34, f"Expected 34 fictional regions, found {len(regions)}"
ids = [item.get("id") for item in regions]
names = [item.get("name") for item in regions]
assert all(ids), "Every region must have an id"
assert len(set(ids)) == len(ids), "Region IDs must be unique"
assert len(set(names)) == len(names), "Region names must be unique"

allowed_owners = {"player", "rival", "neutral"}
for item in regions:
    center = item.get("center")
    assert isinstance(center, list) and len(center) == 2, f"Bad center: {item.get('id')}"
    assert all(isinstance(v, (int, float)) and 0 <= v <= 1 for v in center), f"Out-of-range center: {item.get('id')}"
    assert item.get("initial_owner") in allowed_owners, f"Bad initial owner: {item.get('id')}"
    assert item.get("terrain"), f"Missing terrain: {item.get('id')}"
    assert 1 <= int(item.get("strategic", 0)) <= 5, f"Bad strategic value: {item.get('id')}"

owners = {owner: sum(item["initial_owner"] == owner for item in regions) for owner in allowed_owners}
assert sum(owners.values()) == 34
print(f"Region data OK: {len(regions)} unique regions; initial control {owners}.")

#!/usr/bin/env python3
"""filter_web_data.py — Remove graphics/sound-only fields from extracted JSON."""

import json, sys, os

DATA_DIR = "engine-web/data-web"

FILTERS = {
    "chars.json": {
        "record_key": "chars",
        "remove": ["headId", "attackAnimFrames", "attackAnimDelays", "soundDelays"],
    },
    "items.json": {
        "record_key": "items",
        "remove": ["throwAnim", "displayDesc"],
    },
    "skills.json": {
        "record_key": "skills",
        "remove": ["soundEffect", "animEffect", "unknown1", "unknown2", "unknown3", "unknown4", "unknown5"],
    },
    "scenes.json": {
        "record_key": "scenes",
        "remove": ["exitMusic", "enterMusic"],
    },
}

def main():
    total_removed = 0
    for filename, cfg in FILTERS.items():
        path = os.path.join(DATA_DIR, filename)
        if not os.path.exists(path):
            print(f"  SKIP (not found): {path}")
            continue

        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)

        records = data.get(cfg["record_key"], [])
        removed = 0
        for rec in records:
            for key in cfg["remove"]:
                if key in rec:
                    del rec[key]
                    removed += 1

        data[cfg["record_key"]] = records
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)

        total_removed += removed
        print(f"  {filename}: removed {removed} fields")

    print(f"\nTotal removed: {total_removed} fields")
    return 0

if __name__ == "__main__":
    sys.exit(main())
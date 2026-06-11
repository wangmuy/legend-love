#!/usr/bin/env python3
"""filter_web_data.py — Remove graphics/sound-only fields from extracted JSON."""

import json, sys, os

DATA_DIR = "engine-web/data-web"

FILTERS = {
    "chars.json": {
        "record_key": "chars",
        "remove": ["头像代号", "出招动画帧数", "出招动画延迟", "武功音效延迟"],
    },
    "items.json": {
        "record_key": "items",
        "remove": ["暗器动画编号", "显示物品说明"],
    },
    "skills.json": {
        "record_key": "skills",
        "remove": ["出招音效", "武功动画&音效", "未知1", "未知2", "未知3", "未知4", "未知5"],
    },
    "scenes.json": {
        "record_key": "scenes",
        "remove": ["出口音乐", "入口音乐"],
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
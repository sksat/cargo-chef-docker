#!/usr/bin/env python3
"""ビルドしたイメージの一覧を Actions の job summary 用 markdown にする。

target ごとの検証結果（verify-base-layers.py の --json）と、run 全体の
ジョブ一覧（Actions API）を突き合わせて 1 枚の表にする。ビルドが途中で
落ちた target は JSON が無いので、ジョブの conclusion だけが並ぶ。

usage: render-image-summary.py --jobs jobs.json [--facts DIR]
  jobs.json: gh api /repos/{repo}/actions/runs/{id}/jobs --paginate --jq '.jobs[]' | jq -s '.'
"""
import argparse
import json
import pathlib
import re
import sys

# reusable workflow 経由なのでジョブ名は "<rust version> / <suffix>" になる。
# 各バージョンの prepare は matrix を組むだけなので一覧には出さない
JOB_NAME = re.compile(r"^(\d+\.\d+\.\d+) / (?!prepare$)(.+)$")

# 表の列順。ここに無い platform は後ろにアルファベット順で並べる
PLATFORM_ORDER = ["linux/amd64", "linux/arm64", "linux/386", "linux/arm/v7"]

MARK = {"success": "✅", "failure": "❌", "cancelled": "⏹", "skipped": "⏭"}


def human(n):
    v = float(n)
    for unit in ("B", "KiB", "MiB", "GiB"):
        if v < 1024 or unit == "GiB":
            return f"{v:.1f} {unit}" if unit != "B" else f"{n} B"
        v /= 1024


def vkey(v):
    return [int(x) for x in v.split(".")]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--jobs", required=True, help="Actions API のジョブ一覧 JSON")
    ap.add_argument("--facts", help="verify-base-layers.py の JSON が入ったディレクトリ")
    args = ap.parse_args()

    jobs = json.load(open(args.jobs))
    rows = []
    for job in jobs:
        m = JOB_NAME.match(job["name"])
        if m:
            rows.append(
                {
                    "rust": m.group(1),
                    "suffix": m.group(2),
                    "conclusion": job.get("conclusion") or "in_progress",
                    "url": job.get("html_url"),
                    "facts": None,
                }
            )
    if not rows:
        return 0

    # tag は "<rust version>-<suffix>" なのでファイル名ではなく中身の tag で対応付ける
    facts_by_tag = {}
    if args.facts:
        for path in sorted(pathlib.Path(args.facts).rglob("*.json")):
            facts = json.load(open(path))
            facts_by_tag[facts["tag"]] = facts
    for row in rows:
        row["facts"] = facts_by_tag.get(f"{row['rust']}-{row['suffix']}")

    # 新しいバージョンから並べる。tag に version が入るので rust 列は持たない
    rows.sort(key=lambda r: ([-x for x in vkey(r["rust"])], r["suffix"]))

    used = {p["platform"] for r in rows if r["facts"] for p in r["facts"]["platforms"]}
    plats = [p for p in PLATFORM_ORDER if p in used] + sorted(used - set(PLATFORM_ORDER))
    verified = bool(plats)

    out = ["## イメージ一覧", ""]
    head = ["tag", "build"]
    if verified:
        head += ["ベースと一致"] + [f"`{p}`" for p in plats]
    out.append("| " + " | ".join(head) + " |")
    out.append("|" + "---|" * len(head))

    for row in rows:
        build = MARK.get(row["conclusion"], row["conclusion"])
        if row["url"]:
            build = f"[{build}]({row['url']})"
        cells = [f"`{row['rust']}-{row['suffix']}`", build]
        if verified:
            cells += verification_cells(row["facts"], plats)
        out.append("| " + " | ".join(cells) + " |")

    out.append("")
    if verified:
        base = next(r["facts"]["base"] for r in rows if r["facts"])
        out.append(
            "「ベースと一致」は、publish したイメージのレイヤ列が公式 `rust:<tag>`"
            f"（例 `{base}`）のレイヤ列を接頭辞として持ち、増えているのが"
            " cargo-chef（と `-mold` では mold）の分だけであることの検証。"
        )
        out.append("")
        out.append("platform 列は registry 上の圧縮サイズで、括弧内は公式イメージからの増分。")
    else:
        out.append(
            "レイヤ検証とサイズは publish 済みのイメージを読むため、"
            "push しない run では出ない。"
        )
    print("\n".join(out))
    return 0


def verification_cells(facts, plats):
    if not facts:
        return ["—"] * (1 + len(plats))

    by_plat = {p["platform"]: p for p in facts["platforms"]}
    bad = [p for p in facts["platforms"] if p["status"] != "OK"]
    if bad:
        detail = "、".join(f"{p['platform']}: {p['status']}" for p in bad)
        match = f"❌ {detail}"
    else:
        counts = {(p["base_layers"], p["extra_layers"]) for p in facts["platforms"]}
        if len(counts) == 1:
            base_layers, extra = counts.pop()
            match = f"✅ base {base_layers} + {extra}"
        else:
            match = "✅"

    cells = [match]
    for plat in plats:
        p = by_plat.get(plat)
        if not p or "total_size" not in p:
            cells.append("—")
        else:
            cells.append(f"{human(p['total_size'])} (+{human(p['added_size'])})")
    return cells


if __name__ == "__main__":
    sys.exit(main())

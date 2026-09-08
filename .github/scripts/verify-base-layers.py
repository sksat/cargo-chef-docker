#!/usr/bin/env python3
"""publish したイメージのレイヤ列が、ベースの公式 rust イメージのレイヤ列を
接頭辞として持つことを検証する。

Dockerfile の最終ステージは `FROM rust:<BASE_TAG>` に COPY（mold はさらに apt）を
重ねるだけなので、公式のレイヤはそのまま先頭に並ぶ。崩れていたら、ベースを
作り直しているか、意図しない変更が入っている。

結果は --json で機械可読に書き出せる。Actions ではこれを artifact に上げ、
render-image-summary.py が全 target 分をまとめて 1 枚の表にする。

usage: verify-base-layers.py <image-ref> <base-tag> [--expect-extra N] [--json FILE]
  例: verify-base-layers.py ghcr.io/sksat/cargo-chef-docker:1.91.0-bookworm 1.91.0-bookworm
"""
import argparse
import json
import sys
import urllib.request

IDX = "application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json"
MAN = "application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json"

BASE_REPO = "library/rust"
# ベースはビルドと同じ経路で読む。buildkitd も mirror.gcr.io 経由で pull しており、
# ミラーは Docker Hub と同一の index を返す。直接叩くと pull 上限（未認証で
# IP あたり 100/6h）を検証だけで消費してしまう
DEFAULT_BASE_HOST = "mirror.gcr.io"


def get_json(url, token=None, accept=None):
    headers = {}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    if accept:
        headers["Accept"] = accept
    return json.load(urllib.request.urlopen(urllib.request.Request(url, headers=headers)))


def pull_token(host, repo):
    """匿名 pull 用のトークン。registry ごとに token endpoint が違う。"""
    if host == "mirror.gcr.io":
        return None  # 公開イメージの読み出しに認証は要らない
    if host == "ghcr.io":
        url = f"https://ghcr.io/token?service=ghcr.io&scope=repository:{repo}:pull"
    elif host == "registry-1.docker.io":
        url = f"https://auth.docker.io/token?service=registry.docker.io&scope=repository:{repo}:pull"
    else:
        raise SystemExit(f"token endpoint が未対応の registry: {host}")
    return get_json(url)["token"]


# OCI では arm64 の既定 variant が v8 なので、linux/arm64 と linux/arm64/v8 は同一。
# 我々の index は variant なし、公式 rust は v8 付きで出るため正規化して比較する。
DEFAULT_VARIANT = {"arm64": "v8"}


def platform_key(p):
    variant = p.get("variant")
    if variant and DEFAULT_VARIANT.get(p["architecture"]) == variant:
        variant = None
    return p["os"] + "/" + p["architecture"] + ("/" + variant if variant else "")


def platforms(host, repo, ref, token):
    """index の platform → manifest digest。unknown/unknown（attestation）は除く。"""
    idx = get_json(f"https://{host}/v2/{repo}/manifests/{ref}", token, IDX)
    out = {}
    for m in idx.get("manifests", []):
        p = m["platform"]
        if p["os"] == "unknown":
            continue
        out[platform_key(p)] = m["digest"]
    return out


def layers(host, repo, digest, token):
    man = get_json(f"https://{host}/v2/{repo}/manifests/{digest}", token, MAN)
    return [(l["digest"], l.get("size", 0)) for l in man["layers"]]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("image", help="検証するイメージ（例 ghcr.io/sksat/cargo-chef-docker:1.91.0-bookworm）")
    ap.add_argument("base_tag", help="ベースの公式 rust タグ（例 1.91.0-bookworm）")
    ap.add_argument("--expect-extra", type=int, help="公式より増えているべきレイヤ数")
    ap.add_argument("--json", dest="json_path", help="結果の JSON を書き出す先")
    ap.add_argument(
        "--base-registry", default=DEFAULT_BASE_HOST, help=f"ベースを読む registry（既定 {DEFAULT_BASE_HOST}）"
    )
    args = ap.parse_args()

    host, rest = args.image.split("/", 1)
    repo, ref = rest.rsplit(":", 1)
    base_host = args.base_registry
    ours_token = pull_token(host, repo)
    base_token = pull_token(base_host, BASE_REPO)

    ours = platforms(host, repo, ref, ours_token)
    base = platforms(base_host, BASE_REPO, args.base_tag, base_token)

    results = []
    for plat, digest in sorted(ours.items()):
        r = {"platform": plat}
        if plat not in base:
            r["status"] = f"ベースに {plat} がない"
            results.append(r)
            continue
        ls = layers(host, repo, digest, ours_token)
        bs = layers(base_host, BASE_REPO, base[plat], base_token)
        r["base_layers"] = len(bs)
        r["extra_layers"] = len(ls) - len(bs)
        r["total_size"] = sum(sz for _, sz in ls)
        r["added_size"] = sum(sz for _, sz in ls[len(bs) :])
        if [d for d, _ in ls[: len(bs)]] != [d for d, _ in bs]:
            first = next(
                (i for i, (a, b) in enumerate(zip(ls, bs)) if a[0] != b[0]), min(len(ls), len(bs))
            )
            r["status"] = f"layer[{first}] からベースと相違"
        elif args.expect_extra is not None and r["extra_layers"] != args.expect_extra:
            r["status"] = f"追加レイヤが {r['extra_layers']} 個、期待は {args.expect_extra} 個"
        else:
            r["status"] = "OK"
        results.append(r)

    ok = bool(results) and all(r["status"] == "OK" for r in results)
    for r in results:
        detail = ""
        if "base_layers" in r:
            detail = f" (base {r['base_layers']} + {r['extra_layers']}, total {r['total_size']} B)"
        print(f"  {r['platform']}: {r['status']}{detail}")

    if args.json_path:
        with open(args.json_path, "w") as f:
            json.dump(
                {
                    "image": args.image,
                    "tag": ref,
                    "base": f"{BASE_REPO.split('/')[-1]}:{args.base_tag}",
                    "ok": ok,
                    "platforms": results,
                },
                f,
                indent=2,
            )

    if not ok:
        print(f"::error::{args.image} のレイヤがベース rust:{args.base_tag} と整合しない")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())

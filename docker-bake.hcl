// CI と手元で同一のビルド定義を使う。
//
//   docker buildx bake                    全 base_img を3 platform でビルド
//   docker buildx bake bookworm           1つの base_img だけ
//   docker buildx bake bookworm \
//     --set '*.platform=linux/arm64' \
//     --set '*.tags=cargo-chef:test' --load
//                                         単一 platform を手元に load
//
// CI では docker/metadata-action が吐く bake ファイルを重ねて
// docker-metadata-action target のタグ・ラベル・annotation を差し替える。

// サポートする rust のバージョン。先頭が最新で、latest タグもここから作る。
//
// renovate が追跡するのは先頭（depName コメントが付いている行）だけ。
// renovate.json の autoReplaceStringTemplate により、更新 PR は新しい版を先頭に
// 足して押し出された版を2行目に残す。手で追記する必要はない。
// 2行目以降は追跡対象外なので、patch が出ても上がらない
// （追跡させると版数と同じ数だけ PR が開く）
variable "RUST_VERSIONS" {
  default = [
    # depName=rust packageName=rust datasource=docker
    "1.91.0",
    "1.90.0",
  ]
}

variable "CACHE_REF" {
  default = "ghcr.io/sksat/cargo-chef-docker"
}

// 空でなければ cache-to を有効にする。共有キャッシュへの書き込みは CI だけが行う
variable "CACHE_TO" {
  default = ""
}

// suffix なしのタグ（1.91.0 / 1.91 / latest）を付ける base_img。
// 公式 rust イメージは trixie の行に suffix なしタグを付けている
//   Tags: 1-trixie, 1.98-trixie, 1.98.0-trixie, trixie, 1, 1.98, 1.98.0, latest
variable "DEFAULT_BASE_IMG" {
  default = "trixie"
}

variable "BASE_IMGS" {
  default = ["slim", "trixie", "slim-trixie", "bookworm", "slim-bookworm"]
}

// CI では metadata-action の bake ファイルに上書きされる。
// 手元でビルドするときはこのデフォルトが使われる
target "docker-metadata-action" {
  tags = ["cargo-chef-docker:local"]
}

target "base" {
  inherits   = ["docker-metadata-action"]
  context    = "."
  dockerfile = "Dockerfile"
  platforms  = ["linux/amd64", "linux/386", "linux/arm64", "linux/arm/v7"]
}

target "image" {
  // variant "" が素のイメージ、"-mold" が mold 入り。
  // target 名がそのままタグの suffix になる（1.90.0-bookworm-mold など）
  // target 名にドットは使えないため rust_version の "." を "-" にする。
  // タグに使う値は args から導出する（target 名を分解しない）
  name   = "${replace(rust_version, ".", "-")}-${base_img}${variant}"
  matrix = {
    rust_version = RUST_VERSIONS
    base_img     = BASE_IMGS
    variant      = ["", "-mold"]
  }

  inherits   = ["base"]
  target     = variant == "" ? "default" : "mold"
  args = {
    BASE_TAG     = "${rust_version}-${base_img}"
    RUST_VERSION = rust_version
    # workflow が base なしタグ（1.91.0, 1.91-mold など）の対象を判定するために読む
    IS_DEFAULT_BASE = (base_img == DEFAULT_BASE_IMG) ? "true" : "false"
  }
  cache-from = ["type=registry,ref=${CACHE_REF}:buildcache-${rust_version}-${base_img}${variant}"]
  cache-to   = CACHE_TO == "" ? [] : ["type=registry,ref=${CACHE_REF}:buildcache-${rust_version}-${base_img}${variant},mode=max"]
}

group "default" {
  targets = [
    for t in setproduct(RUST_VERSIONS, BASE_IMGS, ["", "-mold"]) :
    "${replace(t[0], ".", "-")}-${t[1]}${t[2]}"
  ]
}

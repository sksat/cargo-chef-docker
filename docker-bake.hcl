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
// 追従できている rust のリリース。ビルドには使わない。
// renovate がこれを上げると、RUST_VERSIONS が追いつくまで check versions が
// 落ちる。つまり新しいリリースは renovate の PR が赤くなる形で出てくる。
// RUST_VERSIONS は「公式イメージが存在する」バージョンなので、リリース直後は
// イメージがまだ無くて追いつけないことがある。
// 以前は rust-toolchain に置いていたが、あのファイル名は「このリポジトリの
// ビルドに使うツールチェーン」を意味してしまう。ここには Rust のコードが無い
# depName=rust packageName=rust-lang/rust datasource=github-releases
variable "RUST_LATEST_RELEASE" {
  default = "1.98.1"
}

variable "RUST_VERSIONS" {
  default = [
    # depName=rust packageName=rust datasource=docker
    "1.98.1",
    "1.98.0",
    "1.97.1",
    "1.97.0",
    "1.96.1",
    "1.96.0",
    "1.95.0",
    "1.94.1",
    "1.94.0",
    "1.93.1",
    "1.93.0",
    "1.92.0",
    "1.91.1",
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

variable "PLATFORMS" {
  default = ["linux/amd64", "linux/386", "linux/arm64", "linux/arm/v7"]
}

// wild は upstream が x86-64 / ARM64 / RISC-V 向けしか配布しておらず、
// 386 と armv7 は対応対象外。variant ごとに platform を変える
variable "WILD_PLATFORMS" {
  default = ["linux/amd64", "linux/arm64"]
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
  platforms  = PLATFORMS
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
    variant      = ["", "-mold", "-wild"]
  }

  inherits   = ["base"]
  // variant はそのまま最終ステージ名にする（"-mold" -> "mold"）
  target     = variant == "" ? "default" : trimprefix(variant, "-")
  platforms  = variant == "-wild" ? WILD_PLATFORMS : PLATFORMS
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
    for t in setproduct(RUST_VERSIONS, BASE_IMGS, ["", "-mold", "-wild"]) :
    "${replace(t[0], ".", "-")}-${t[1]}${t[2]}"
  ]
}

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

variable "RUST_VERSION" {
  # depName=rust datasource=docker
  default = "1.90.0"
}

variable "CACHE_REF" {
  default = "ghcr.io/sksat/cargo-chef-docker"
}

// 空でなければ cache-to を有効にする。共有キャッシュへの書き込みは CI だけが行う
variable "CACHE_TO" {
  default = ""
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
  name   = base_img
  matrix = { base_img = BASE_IMGS }

  inherits   = ["base"]
  args       = { BASE_TAG = "${RUST_VERSION}-${base_img}" }
  cache-from = ["type=registry,ref=${CACHE_REF}:buildcache-${base_img}"]
  cache-to   = CACHE_TO == "" ? [] : ["type=registry,ref=${CACHE_REF}:buildcache-${base_img},mode=max"]
}

group "default" {
  targets = BASE_IMGS
}

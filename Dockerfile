# syntax=docker/dockerfile:1.27.0

ARG BASE_IMG=rust
# depName=rust datasource=docker
ARG RUST_VERSION="1.98.1"
ARG BASE_TAG=${RUST_VERSION}
# workflow が base なしタグの対象を判定するために bake が渡す。
# ビルドでは参照しないが、宣言しないと未使用 build arg の警告が出る
ARG IS_DEFAULT_BASE

# cargo-chef をクロスコンパイルする。BUILDPLATFORM に固定することで、
# rustc を QEMU 上で動かさずに済ませる（TARGETPLATFORM で動かすと桁違いに遅い）
FROM --platform=${BUILDPLATFORM} ${BASE_IMG}:${BASE_TAG} AS build

# depName=LukeMathWalker/cargo-chef datasource=github-releases
ARG CARGO_CHEF_VERSION="v0.1.78"
ARG TARGETPLATFORM
ARG BUILDPLATFORM

RUN set -eux; \
    case "${TARGETPLATFORM}" in \
      linux/amd64)   target=x86_64-unknown-linux-gnu;      pkgs='g++-x86-64-linux-gnu libc6-dev-amd64-cross';    linker=x86_64-linux-gnu-gcc ;; \
      linux/386)     target=i686-unknown-linux-gnu;        pkgs='g++-i686-linux-gnu libc6-dev-i386-cross';       linker=i686-linux-gnu-gcc ;; \
      linux/arm64)   target=aarch64-unknown-linux-gnu;     pkgs='g++-aarch64-linux-gnu libc6-dev-arm64-cross';   linker=aarch64-linux-gnu-gcc ;; \
      linux/arm/v7)  target=armv7-unknown-linux-gnueabihf; pkgs='g++-arm-linux-gnueabihf libc6-dev-armhf-cross';  linker=arm-linux-gnueabihf-gcc ;; \
      linux/riscv64) target=riscv64gc-unknown-linux-gnu;   pkgs='g++-riscv64-linux-gnu libc6-dev-riscv64-cross'; linker=riscv64-linux-gnu-gcc ;; \
      *) echo "unsupported TARGETPLATFORM: ${TARGETPLATFORM}" >&2; exit 1 ;; \
    esac; \
    # ネイティブビルドならクロスツールチェーンも linker 指定も不要
    if [ "${TARGETPLATFORM}" = "${BUILDPLATFORM}" ]; then pkgs=''; linker=''; fi; \
    apt-get update; \
    apt-get install --no-install-recommends -y curl ${pkgs}; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*; \
    rustup target add "${target}"; \
    if [ -n "${linker}" ]; then \
      export "CARGO_TARGET_$(echo "${target}" | tr 'a-z-' 'A-Z_')_LINKER=${linker}"; \
    fi; \
    cargo install cargo-chef --target="${target}" --version "${CARGO_CHEF_VERSION#v}" --locked

FROM ${BASE_IMG}:${BASE_TAG} AS default
# 公式 rust イメージの CARGO_HOME。COPY ではベースイメージ由来の ENV に頼らず明示する
ARG CARGO_BIN=/usr/local/cargo/bin
COPY --from=build ${CARGO_BIN}/cargo-chef ${CARGO_BIN}/cargo-chef

# wild は upstream が glibc 版のバイナリを配布している。要求する glibc は
# 2.34 までなので bookworm(2.36) でも trixie(2.41) でも動く。
# build ステージを土台にするのは curl が入っているためで、default が既に
# 依存しているので追加のコストはない
FROM build AS wild-dist

# depName=wild-linker/wild datasource=github-releases
ARG WILD_VERSION="0.10.0"
# ダウンロードした tarball を検証する。upstream は checksum ファイルも署名も
# 出しておらず、release API の digest だけがある。ここに固定しておけば、
# 同名アセットが差し替えられた場合に気づける。
# バージョンを上げたときの更新:
#   gh api /repos/wild-linker/wild/releases/tags/<version> \
#     --jq '.assets[] | select(.name|endswith("-unknown-linux-gnu.tar.gz")) | "\(.name) \(.digest)"'
ARG WILD_SHA256_X86_64="641265506a7c06cfb03181b8916ab663ec8407855db6d4db7f8450667d105283"
ARG WILD_SHA256_AARCH64="e9d670e41f76481a68984f816e25bd2f124664db3ac935053e1a6fc41d2894c2"
ARG TARGETPLATFORM

RUN set -eux; \
    case "${TARGETPLATFORM}" in \
      linux/amd64) arch=x86_64;  sha="${WILD_SHA256_X86_64}" ;; \
      linux/arm64) arch=aarch64; sha="${WILD_SHA256_AARCH64}" ;; \
      # bake の WILD_PLATFORMS で絞っているので通常ここには来ない
      *) echo "wild does not support ${TARGETPLATFORM}" >&2; exit 1 ;; \
    esac; \
    name="wild-linker-${WILD_VERSION}-${arch}-unknown-linux-gnu"; \
    # --retry だけでは timeout と一部の HTTP コードしか再試行されず、
    # 実際に出た接続リセット（exit 35）は対象外なので --retry-all-errors。
    # このフラグは pipe 先だと部分転送が重複しうるため、ファイルに落とす
    curl -fsSL --retry 3 --retry-delay 2 --retry-all-errors --max-time 180 \
      -o /tmp/wild.tar.gz \
      "https://github.com/wild-linker/wild/releases/download/${WILD_VERSION}/${name}.tar.gz"; \
    echo "${sha}  /tmp/wild.tar.gz" | sha256sum -c - \
      || { echo "wild ${WILD_VERSION} (${arch}) の sha256 が合わない。バージョンを上げたなら ARG も更新する" >&2; exit 1; }; \
    # 展開は捨てるステージの /tmp だが、アーカイブ側の owner を持ち込まない
    tar xzf /tmp/wild.tar.gz --no-same-owner -C /tmp; \
    install -Dm755 "/tmp/${name}/wild" /out/wild

# variant は default の上に積まず、ベースから作って cargo-chef と linker を
# 同じ RUN で置く。FROM default にすると公式イメージに対して 2 層になる。
# mount 元は build ステージ側の CARGO_HOME で、置き先の CARGO_BIN とは別物。
# ディレクトリごと COPY すると公式が CARGO_HOME に付けている a+w が 755 に
# 戻るため、install -D でファイルだけ置く

# -mold タグ用。mold を入れるだけで、cargo が使う設定は入れない
FROM ${BASE_IMG}:${BASE_TAG} AS mold
ARG CARGO_BIN=/usr/local/cargo/bin
RUN --mount=from=build,source=/usr/local/cargo/bin,target=/payload \
    set -eux; \
    install -Dm755 /payload/cargo-chef "${CARGO_BIN}/cargo-chef"; \
    apt-get update; \
    apt-get install --no-install-recommends -y mold; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

# -wild タグ用。mold と同じく、置くだけで cargo の設定は入れない
FROM ${BASE_IMG}:${BASE_TAG} AS wild
ARG CARGO_BIN=/usr/local/cargo/bin
RUN --mount=from=build,source=/usr/local/cargo/bin,target=/payload \
    --mount=from=wild-dist,source=/out,target=/wild \
    set -eux; \
    install -Dm755 /payload/cargo-chef "${CARGO_BIN}/cargo-chef"; \
    install -Dm755 /wild/wild /usr/local/bin/wild; \
    # clang の -fuse-ld=wild は ld.wild を探す
    ln -s wild /usr/local/bin/ld.wild; \
    # gcc の -B<dir> 用。apt の mold が /usr/libexec/mold/ld を置くのと同じ形
    install -d /usr/local/libexec/wild; \
    ln -s ../../bin/wild /usr/local/libexec/wild/ld

# 最後のステージが --target なしのビルド対象になる。
# mold を末尾に置くと素の `docker build .` が mold 版になってしまうため、
# default の別名を最後に置く
FROM default

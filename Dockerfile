# syntax=docker/dockerfile:1

ARG BASE_IMG=rust
# depName=rust datasource=docker
ARG RUST_VERSION="1.90.0"
ARG BASE_TAG=${RUST_VERSION}

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
      linux/arm64)   target=aarch64-unknown-linux-gnu;     pkgs='g++-aarch64-linux-gnu libc6-dev-arm64-cross';   linker=aarch64-linux-gnu-gcc ;; \
      linux/386)     target=i686-unknown-linux-gnu;        pkgs='g++-i686-linux-gnu libc6-dev-i386-cross';       linker=i686-linux-gnu-gcc ;; \
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

FROM ${BASE_IMG}:${BASE_TAG}
# 公式 rust イメージの CARGO_HOME。COPY ではベースイメージ由来の ENV に頼らず明示する
ARG CARGO_BIN=/usr/local/cargo/bin
COPY --from=build ${CARGO_BIN}/cargo-chef ${CARGO_BIN}/cargo-chef

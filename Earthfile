VERSION 0.6

# depName=rust datasource=docker
ARG RUST_VERSION="1.88.0"

ARG BASE_IMG=rust   # default image
ARG BASE_TAG=${RUST_VERSION} # default tag

# DOCKER_META_VERSION should not be here for cache

FROM ${BASE_IMG}:${BASE_TAG}

# depName=LukeMathWalker/cargo-chef datasource=github-releases
ARG CARGO_CHEF_VERSION="v0.1.71"

build-amd64:
  RUN apt-get update && apt-get install --no-install-recommends -y curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
  RUN cargo install cargo-chef --version ${CARGO_CHEF_VERSION#v} --locked
  SAVE ARTIFACT ${CARGO_HOME}/bin/cargo-chef
  SAVE IMAGE --cache-hint

build-arm64:
  RUN apt-get update && apt-get install --no-install-recommends -y curl g++-aarch64-linux-gnu libc6-dev-arm64-cross \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
  RUN rustup target add aarch64-unknown-linux-gnu
  ENV CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER=aarch64-linux-gnu-gcc
  RUN cargo install cargo-chef --target=aarch64-unknown-linux-gnu --version ${CARGO_CHEF_VERSION#v} --locked
  #RUN file ${CARGO_HOME}/bin/cargo-chef
  SAVE ARTIFACT ${CARGO_HOME}/bin/cargo-chef
  SAVE IMAGE --cache-hint

build-i686:
  RUN apt-get update && apt-get install --no-install-recommends -y curl g++-i686-linux-gnu libc6-dev-i386-cross \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
  RUN rustup target add i686-unknown-linux-gnu
  ENV CARGO_TARGET_I686_UNKNOWN_LINUX_GNU_LINKER=i686-linux-gnu-gcc
  RUN cargo install cargo-chef --target=i686-unknown-linux-gnu --version ${CARGO_CHEF_VERSION#v} --locked
  #RUN file ${CARGO_HOME}/bin/cargo-chef
  SAVE ARTIFACT ${CARGO_HOME}/bin/cargo-chef
  SAVE IMAGE --cache-hint

build-riscv64gc:
  RUN apt-get update && apt-get install --no-install-recommends -y curl g++-riscv64-linux-gnu libc6-dev-riscv64-cross \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
  RUN rustup target add riscv64gc-unknown-linux-gnu
  ENV CARGO_TARGET_RISCV64GC_UNKNOWN_LINUX_GNU_LINKER=riscv64-linux-gnu-gcc
  RUN cargo install cargo-chef --target=riscv64gc-unknown-linux-gnu --version ${CARGO_CHEF_VERSION#v} --locked
  #RUN file ${CARGO_HOME}/bin/cargo-chef
  SAVE ARTIFACT ${CARGO_HOME}/bin/cargo-chef
  SAVE IMAGE --cache-hint

docker-amd64:
  ARG DOCKER_META_VERSION
  COPY +build-amd64/cargo-chef ${CARGO_HOME}/bin/
  SAVE IMAGE ghcr.io/sksat/cargo-chef-docker:${BASE_TAG}-${DOCKER_META_VERSION}

docker-arm64:
  FROM --platform=linux/arm64 ${BASE_IMG}:${BASE_TAG}
  ARG DOCKER_META_VERSION
  COPY +build-arm64/cargo-chef ${CARGO_HOME}/bin/
  #RUN file ${CARGO_HOME}/bin/cargo-chef
  #RUN cargo chef --version
  SAVE IMAGE ghcr.io/sksat/cargo-chef-docker:${BASE_TAG}-${DOCKER_META_VERSION}

docker-i686:
  FROM --platform=linux/386 ${BASE_IMG}:${BASE_TAG}
  ARG DOCKER_META_VERSION
  COPY +build-i686/cargo-chef ${CARGO_HOME}/bin/
  SAVE IMAGE ghcr.io/sksat/cargo-chef-docker:${BASE_TAG}-${DOCKER_META_VERSION}

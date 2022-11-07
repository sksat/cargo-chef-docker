VERSION 0.6

ARG BASE_IMG=rust   # default image
ARG BASE_TAG=latest # default tag

# DOCKER_META_VERSION should not be here for cache

FROM ${BASE_IMG}:${BASE_TAG}

# depName=LukeMathWalker/cargo-chef datasource=github-releases
ARG CARGO_CHEF_VERSION="v0.1.46"

build-amd64:
  RUN apt-get update && apt-get install --no-install-recommends -y curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
  COPY cargo_install.sh ${CARGO_HOME}/bin/
  RUN cargo_install.sh cargo-chef ${CARGO_CHEF_VERSION}
  SAVE ARTIFACT ${CARGO_HOME}/bin/cargo-chef
  SAVE IMAGE --cache-hint

build-arm64:
  RUN apt-get update && apt-get install --no-install-recommends -y curl g++-aarch64-linux-gnu libc6-dev-arm64-cross \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
  COPY cargo_install.sh /usr/local/bin/
  RUN rustup target add aarch64-unknown-linux-gnu
  ENV CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER=aarch64-linux-gnu-gcc
  RUN cargo install cargo-chef --target=aarch64-unknown-linux-gnu --version ${CARGO_CHEF_VERSION#v} --locked
  RUN file ${CARGO_HOME}/bin/cargo-chef
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

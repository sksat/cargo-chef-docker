VERSION 0.6

ARG BASE_IMG=rust   # default image
ARG BASE_TAG=latest # default tag

# depName=LukeMathWalker/cargo-chef datasource=github-releases
ARG CARGO_CHEF_VERSION="v0.1.46"

build:
  FROM ${BASE_IMG}:${BASE_TAG}
  RUN apt-get update && apt-get install --no-install-recommends -y curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
  COPY cargo_install.sh /usr/local/bin/
  RUN cargo_install.sh cargo-chef ${CARGO_CHEF_VERSION}

build-arm64:
  FROM ${BASE_IMG}:${BASE_TAG}
  RUN apt-get update && apt-get install --no-install-recommends -y curl g++-aarch64-linux-gnu libc6-dev-arm64-cross \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
  COPY cargo_install.sh /usr/local/bin/
  RUN rustup target add aarch64-unknown-linux-gnu
  ENV CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER=aarch64-linux-gnu-gcc
  RUN cargo install cargo-chef --version ${CARGO_CHEF_VERSION#v} --locked
  RUN file ${CARGO_HOME}/bin/cargo-chef

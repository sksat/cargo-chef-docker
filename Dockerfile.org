ARG BASE_IMG=rust   # default image
ARG BASE_TAG=latest # default tag
FROM ${BASE_IMG}:${BASE_TAG}

LABEL maintainer "sksat <sksat@sksat.net>"

# depName=LukeMathWalker/cargo-chef datasource=github-releases
ARG CARGO_CHEF_VERSION="v0.1.38"

RUN cargo install --version "${CARGO_CHEF_VERSION#v}" --locked cargo-chef \
  && rm -rf "${CARGO_HOME}"/registry/

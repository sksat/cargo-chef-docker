ARG BASE_IMG=rust:latest # default image
FROM ${BASE_IMG}

LABEL maintainer "sksat <sksat@sksat.net>"

# depName=LukeMathWalker/cargo-chef datasource=github-releases
ARG CARGO_CHEF_VERSION="v0.1.33"

RUN ( (< /etc/os-release grep "alpine") && apk add --no-cache musl-dev=1.2.2-r7 --repository="http://dl-cdn.alpinelinux.org/alpine/v3.14/main" || true) \
  && cargo install --version "${CARGO_CHEF_VERSION#v}" --locked cargo-chef \
  && rm -rf "${CARGO_HOME}"/registry/

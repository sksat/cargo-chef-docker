ARG BASE_IMG=rust:latest # default image
FROM ${BASE_IMG}

LABEL maintainer "sksat <sksat@sksat.net>"

RUN ((cat /etc/os-release | grep "alpine") && apk add --no-cache musl-dev=1.2.2-r3 --repository="http://dl-cdn.alpinelinux.org/alpine/v3.14/main" || true) \
  && cargo install cargo-chef \
  && rm -rf ${CARGO_HOME}/registry/

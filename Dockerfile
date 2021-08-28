ARG BASE_IMG=rust:latest # default image
FROM $BASE_IMG

LABEL maintainer "sksat <sksat@sksat.net>"

RUN ((cat /etc/os-release | grep alpine) && apk add --no-cache musl-dev || true) \
  && cargo install cargo-chef \
  && rm -rf $CARGO_HOME/registry/

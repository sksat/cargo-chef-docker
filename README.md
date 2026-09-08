# cargo-chef-docker

[![build container](https://github.com/sksat/cargo-chef-docker/actions/workflows/build-image.yml/badge.svg)](https://github.com/sksat/cargo-chef-docker/actions/workflows/build-image.yml)
[![license](https://img.shields.io/github/license/sksat/cargo-chef-docker)](LICENSE)
[![docker pulls](https://img.shields.io/docker/pulls/sksat/cargo-chef-docker)](https://hub.docker.com/r/sksat/cargo-chef-docker)
[![latest-bookworm](https://img.shields.io/docker/image-size/sksat/cargo-chef-docker/latest-bookworm?label=latest-bookworm)](https://hub.docker.com/r/sksat/cargo-chef-docker/tags)
[![latest-slim-bookworm](https://img.shields.io/docker/image-size/sksat/cargo-chef-docker/latest-slim-bookworm?label=latest-slim-bookworm)](https://hub.docker.com/r/sksat/cargo-chef-docker/tags)

Official [rust](https://hub.docker.com/_/rust) images with
[cargo-chef](https://github.com/LukeMathWalker/cargo-chef) already installed, so
your Dockerfile can start caching dependencies without a `cargo install` step.

Published to both registries, same tags:

- `ghcr.io/sksat/cargo-chef-docker`
- `sksat/cargo-chef-docker`

## Usage

```dockerfile
FROM ghcr.io/sksat/cargo-chef-docker:latest-bookworm AS chef
WORKDIR /app

FROM chef AS planner
COPY . .
RUN cargo chef prepare --recipe-path recipe.json

FROM chef AS builder
COPY --from=planner /app/recipe.json recipe.json
# dependencies are cached as long as recipe.json does not change
RUN cargo chef cook --release --recipe-path recipe.json
COPY . .
RUN cargo build --release
```

## Tags

| shape | example | notes |
|---|---|---|
| `<rust>-<base>` | `1.91.0-bookworm` | pinned rust version |
| `latest-<base>` | `latest-bookworm` | newest rust version built here |
| `<rust>-<base>-mold` | `1.91.0-bookworm-mold` | see [mold](#mold) |
| `sha-<sha>-<rust>-<base>` | `sha-40da647-1.91.0-bookworm` | a single commit of this repository |

`<base>` is one of `slim`, `trixie`, `slim-trixie`, `bookworm`, `slim-bookworm`,
matching the [official rust image](https://hub.docker.com/_/rust) variant. Note
that `slim` tracks whichever Debian the rust image defaults to, currently
trixie.

Several rust versions are built at once; the set is listed in
[`docker-bake.hcl`](docker-bake.hcl). Older versions keep being rebuilt, so they
pick up newer cargo-chef releases, and they are not removed when a new version
is added.

## Platforms

Every tag is a multi-arch index covering:

`linux/amd64`, `linux/386`, `linux/arm64`, `linux/arm/v7`

`docker pull` picks the right one, so `docker pull …:latest-bookworm` on an Apple
Silicon Mac gets the arm64 image.

## mold

The `-mold` tags add the [mold](https://github.com/rui314/mold) linker from apt.
**Nothing is configured for cargo** — the binary is there and you opt in:

```dockerfile
ENV RUSTFLAGS="-C link-arg=-fuse-ld=mold"
```

The version comes from the base image's Debian release, so bookworm gives an
older mold than trixie.

## Building locally

The build is defined in [`docker-bake.hcl`](docker-bake.hcl) and CI uses the same
file:

```sh
# every version, base image and variant
docker buildx bake

# one target
docker buildx bake 1-91-0-bookworm

# load a single platform into the local daemon
docker buildx bake 1-91-0-bookworm \
  --set '*.platform=linux/arm64' \
  --set '*.tags=cargo-chef:test' --load
```

Target names replace the dots in the version, because bake does not allow them.

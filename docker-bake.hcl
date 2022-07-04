// docker-bake.hcl
target "docker-metadata-action" {}

target "build" {
  inherits = ["docker-metadata-action"]
  context = "./"
  dockerfile = "Dockerfile"
  platforms = [
    "linux/amd64",
    #"linux/arm/v6",
    #"linux/arm/v7",
    #"linux/arm64",
    #"linux/386",
  ]
}

group "default" {
  targets = [
    "slim",
    "buster",
    "slim-buster",
    "bullseye",
    "slim-bullseye",
    "alpine",
  ]
}

variable "DOCKER_META_VERSION" {
  default = "latest"
}
variable "DOCKER_BASE_TAG" {
  default = "latest"
}

target "base" {
  context = "./"
  dockerfile = "./Dockerfile"
  tags = ["sksat/cargo-chef-docker:${DOCKER_BASE_TAG}-${DOCKER_META_VERSION}"]
}

target "slim" {
  inherits = ["base"]
  args = { BASE_TAG = "slim" }
}
target "buster" {
  inherits = ["base"]
  args = { BASE_TAG = "buster" }
}
target "slim-buster" {
  inherits = ["base"]
  args = { BASE_TAG = "slim-buster" }
}
target "bullseye" {
  inherits = ["base"]
  args = { BASE_TAG = "bullseye" }
}
target "slim-bullseye" {
  inherits = ["base"]
  args = { BASE_TAG = "slim-bullseye" }
}
target "alpine" {
  inherits = ["base"]
  dockerfile = "./Dockerfile.alpine"
  args = { BASE_TAG = "alpine" }
}

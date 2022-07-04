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

target "base" {
  context = "./"
  dockerfile = "./Dockerfile"
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
  args = { BASE_TAG = "alpine" }
}

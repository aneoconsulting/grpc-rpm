# gRPC RPM Builder (UBI8)

This repository contains a Dockerfile to build RPM packages for gRPC on top of Red Hat UBI 8.  
It sets up an RPM build environment, compiles gRPC from source, and produces installable RPM packages.

## Overview

The container performs the following steps:

1. Uses UBI 8 as the base image.
2. Enables the EPEL repository.
3. Installs build tools and dependencies.
4. Installs rpmdevtools and sets up the RPM build tree.
5. Downloads the specified gRPC version from GitHub.
6. Creates an RPM source tarball.
7. Generates an RPM spec file.
8. Builds:
   - grpc
   - grpc-devel
9. Copies the resulting RPM files to /tmp/rpms.

## Configurable Build Arguments

The Dockerfile exposes two build arguments:

| Argument | Default | Description |
|----------|---------|-------------|
| GRPC_VERSION | 1.62.2 | Version of gRPC to build |
| PARALLEL_JOBS | 4 | Number of parallel jobs used during compilation |

Example:

```bash
docker build \
  --build-arg GRPC_VERSION=1.60.0 \
  --build-arg PARALLEL_JOBS=8 \
  -t grpc-rpm-builder .
```

## Building the Image

```bash
docker build -t grpc-rpm-builder .
```

## Building the RPM Packages

Run the container and mount a directory to retrieve the RPM files:

```bash
docker run --rm -v $(pwd)/rpms:/tmp/rpms grpc-rpm-builder
```

## What Gets Built

The spec file produces two packages.

### grpc

Contains:

- gRPC binaries
- static libraries
- CLI tools (grpc_*, protoc, etc.)
- root certificates

### grpc-devel

Development package containing:

- headers
- CMake configuration files
- pkg-config files
- dependencies required to build applications using gRPC

## Notes

- Libraries are built statically (BUILD_SHARED_LIBS=OFF).
- Tests are disabled to reduce build time.
- Some dependencies (Abseil, Protobuf, c-ares) are built as bundled modules and hence should be **statically linked** in the codes using the generated rpm packages.

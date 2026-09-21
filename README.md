# docker-node-minimal

A minimal Docker image with just Node.js.

The image starts from `scratch` and contains only a fully static Node.js binary compiled from source with [build.sh](build.sh). There is no OS, shell, or package manager. Multi-arch manifests are published for `linux/amd64` and `linux/arm64`.

## Tags

Every published build is available from both registries with the following tags:

| Tag | Description |
| --- | ----------- |
| `20.10.0` | Exact Node.js version |
| `20` | Major version (latest release of that major) |
| `current` | Always the latest daily build |
| `latest` | Most recent release |

## Use the Docker Hub Image

This image is published to Docker Hub:

<https://hub.docker.com/r/chorrell/node-minimal>

To pull the latest node-minimal image:

```sh
docker pull chorrell/node-minimal:latest
```

To pull a specific version:

```sh
docker pull chorrell/node-minimal:20.10.0
```

## Use the GitHub Container Image

This image is published to the GitHub Container Registry:

<https://github.com/chorrell/docker-node-minimal/pkgs/container/node-minimal>

To pull the latest node-minimal image:

```sh
docker pull ghcr.io/chorrell/node-minimal:latest
```

To pull a specific version:

```sh
docker pull ghcr.io/chorrell/node-minimal:20.10.0
```

## Usage

The entrypoint is the Node.js binary itself, so arguments are passed straight to Node:

```sh
docker run --rm chorrell/node-minimal:latest -e "console.log('Hello from Node.js ' + process.version)"
```

To run a script, mount it into the container and pass its path:

```sh
docker run --rm -v "$PWD:/app" -w /app chorrell/node-minimal:latest app.js
```

## Building from Source

Node.js is compiled from source as a fully static binary by `build.sh`, then copied into the scratch image by the [Dockerfile](Dockerfile):

```sh
./build.sh -n 20.10.0
cp node-src/out/Release/node node
docker build -t node-minimal .
```

See [AGENTS.md](AGENTS.md) for the full development guide and [SETUP.md](SETUP.md) for local pre-commit hook setup.

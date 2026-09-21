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

## Static builds and `--without-intl`

`build.sh` configures Node with `--fully-static`, which appends `-static` to every link command in the generated makefiles. That includes build-time host tools and shared libraries that only work when linked dynamically, and upstream this remains broken ([nodejs/node#41497](https://github.com/nodejs/node/issues/41497); the fix proposed in [nodejs/node#30199](https://github.com/nodejs/node/pull/30199) was never merged). The build works today because:

- `--without-intl` sets `v8_enable_i18n_support=0`, which keeps `gen-regexp-special-case` — a V8 host tool that segfaults when linked with `-static` ([nodejs/node#30180](https://github.com/nodejs/node/issues/30180)) — out of the default `make` dependency graph, so it is never built or run.
- Node 18.0.0 removed the `test_crypto_engine` test fixture from the default build ([nodejs/node#41830](https://github.com/nodejs/node/pull/41830)). It is a shared library, and `-shared` cannot be combined with `-static` — the linker error in #41497. It is now only built when running the test suite.

This repo previously worked around both by stripping `-static` from those targets' generated makefiles after `./configure`, as suggested in [nodejs/node#41497 (comment)](https://github.com/nodejs/node/issues/41497#issuecomment-1013137433). Since Node 18, neither target participates in the default build, so the patch was removed.

If the static build fails again after dropping `--without-intl` — or after a future Node release reintroduces a shared library into the default build — expect a linker error like `crtbeginT.o: relocation ... can not be used when making a shared object` or a `gen-regexp-special-case` crash during `make`. The fix is to re-apply the patch: after `./configure`, strip `-static` from the affected generated makefiles (for example `out/tools/v8_gypfiles/gen-regexp-special-case.target.mk`) before running `make`.

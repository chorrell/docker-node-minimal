# AGENTS.md - Development Guide for AI Agents

## Quick Start

This repository builds minimal Node.js Docker images. To build and test locally:

```bash
# Build Node.js binary for a specific version
./build.sh -n 20.10.0

# Copy the compiled binary into the build context (expected by the Dockerfile)
cp node-src/out/Release/node node

# Test the generated binary
docker build -t node-minimal .
docker run --rm node-minimal -e "console.log('Hello from Node.js ' + process.version)"
```

## Build Process

The `build.sh` script compiles Node.js from source as a static binary:

- **Usage:** `./build.sh -n NODE_VERSION`
- **Example:** `./build.sh -n 20.10.0`
- **Output:** Extracts to a version-independent `node-src/` directory and creates the compiled Node.js binary there. Building in a stable directory name (rather than `node-v$VERSION/`) lets ccache reuse compiled objects across Node version bumps, since unchanged files no longer get a different cache key just because the version changed.
- **Configuration:** Uses `--fully-static --without-npm --without-intl` flags. `--without-intl` is also what keeps the static build working without patching generated makefiles; see "Static builds and `--without-intl`" in [README.md](./README.md)
- **Duration:** Compilation takes 10-30 minutes on a cold cache; a warm ccache (e.g. a patch version bump) can be substantially faster

## Dockerfile

The minimal Dockerfile uses `FROM scratch` and copies only the Node.js binary:

```dockerfile
# syntax=docker/dockerfile:1
FROM scratch
LABEL maintainer=christopher@horrell.ca
LABEL org.opencontainers.image.source=https://github.com/chorrell/docker-node-minimal
COPY --link node /bin/
ENTRYPOINT ["/bin/node"]
```

## CI/CD Workflows

### dockerimage.yml

- Builds Docker images on PR changes to `Dockerfile`, `build.sh`, `get-build-targets.sh`, or the workflow file itself
- Tests on both linux/amd64 and linux/arm64 platforms
- Uses ccache for faster compilation, with a separate cache per Node.js major version
- Builds the latest Current release and the latest release of every supported LTS line (via `get-build-targets.sh -a`)

### update-current-image.yml

- Runs daily on schedule (cron: `30 0 * * *`), or manually via `workflow_dispatch` with an optional `node_version` input
- Resolves build targets (via `get-build-targets.sh`): the latest Current release and the latest release of every supported LTS line, if not yet on Docker Hub, or the provided version
- Builds each target for both platforms and publishes to Docker Hub and GitHub Container Registry
- Tags each target with the tags computed by `get-build-targets.sh` (see Versioning)
- Signs the compiled Node.js binary and the merged image indexes with GitHub artifact attestations (`actions/attest@v4`, pinned SHA) for GHCR and Docker Hub

### linting.yml

- Runs on all pull requests
- Validates shell script formatting with shfmt (direct binary, not Docker)
- Runs shellcheck for shell script linting
- Runs markdownlint-cli2 for Markdown linting

## Scripts

### build.sh

Compiles Node.js statically:

- Fetches GPG keys for signature verification
- Downloads Node.js source tarball and checksums
- Verifies GPG signature
- Configures with fully-static compilation flags
- Compiles with optimal parallelization

### get-build-targets.sh

Resolves which Node.js versions to build and how to tag them:

- Queries the Node.js distribution API (nodejs.org/dist/index.json)
- Filters out known broken builds (SKIP_VERSIONS array)
- Queries the Node.js release schedule (nodejs/Release schedule.json) for end-of-life dates
- Picks the latest Current release and the latest release of each LTS line that hasn't reached end-of-life, ordered by version (not release date)
- Checks Docker Hub API to drop targets that are already published (does not count against pull rate limits)
- Prints a JSON array of `{version, major, tags}` used as the workflow build matrix
- Usage: `./get-build-targets.sh` (missing targets), `./get-build-targets.sh -a` (all targets), `./get-build-targets.sh -n 24.21.0` (tags for a specific version)
- `NODE_INDEX_URL`, `NODE_SCHEDULE_URL`, and `TODAY` override the release index, release schedule, and current date (e.g. `file://` fixtures in tests)

## Code Quality

- **Workflow Security:** All workflows under `.github/` must pass a [zizmor](https://docs.zizmor.sh/) audit (`zizmor .github/workflows/`) with no unsuppressed findings before merging
- **Linting & Formatting:** Enforced via `linting.yml` in CI (shfmt, shellcheck, markdownlint-cli2) and locally via pre-commit hooks
- **Pre-commit hooks:** `.pre-commit-config.yaml` enforces the following checks locally before commit (some run via Docker, others via native binaries):
  - `actionlint` - lints GitHub Actions workflow files
  - `gitleaks` - scans for leaked secrets
  - `markdownlint-cli2-docker` on all `.md` files (markdown linting with `.markdownlint.yaml` config)
  - Standard `pre-commit-hooks`: trailing-whitespace, end-of-file-fixer, check-yaml, check-merge-conflict, check-added-large-files, mixed-line-ending
  - `shfmt-docker` on all `.sh` and `.bats` files (auto-formatting with `-sr -i 2 -w -ci` flags)
  - `shellcheck` on all `.sh` and `.bats` files (shell script linting)
  - `zizmor` - GitHub Actions workflow security audit
  - See [SETUP.md](./SETUP.md) for detailed installation instructions
  - Quick start: `pre-commit install` then hooks run automatically on commit (requires Docker)
- **Branch Protection:** main branch requires passing checks and code owner review

## Testing

### Unit Tests

Bats test suite for get-build-targets.sh:

- Run tests: `bats test/get-build-targets.bats`
- Tag resolution tests run offline against fixture release indexes in `test/fixtures/`, covering:
  - Input validation (`-n` version format, unknown and skipped versions)
  - Help/usage output
  - Current, Active LTS, and Maintenance LTS target selection and tags
  - End-of-life LTS lines being dropped
  - `latest` ordering by version, and the gap where no Current release exists
  - SKIP_VERSIONS fallback
  - Tags for manually requested versions
- One integration test runs against the live release index and Docker Hub

### Integration Tests

Integration tests run in CI:

- Build Docker image with latest Node.js
- Execute JavaScript code via docker run
- Verify Node.js version output

## Dependencies

External dependencies:

- curl - downloads Node.js sources and GPG keys (build.sh)
- gpg - verifies GPG signatures (build.sh)
- tar - extracts Node.js source (build.sh)
- gcc/make - compiles Node.js from source (build.sh)
- jq - parses the Node.js release index (get-build-targets.sh and CI workflows)
- bats - runs the unit test suite (test/get-build-targets.bats)
- Docker - for building and testing Docker image

## Versioning

Images are tagged with:

- Exact version: `24.21.0` (every build)
- Major version: `24` (newest release of that major)
- LTS codename: `krypton` (newest release of that LTS line)
- LTS: `lts` (newest Active LTS release)
- Current: `current` (the latest Node.js "Current" release; not moved while no Current line exists)
- Latest: `latest` (highest version overall, usually the same as `current`)

Published to:

- Docker Hub: `chorrell/node-minimal:TAG`
- GitHub Container Registry: `ghcr.io/chorrell/node-minimal:TAG`

## Environment Variables

Required for publishing (GitHub Actions secrets):

- `DOCKERHUB_USERNAME` - Docker Hub username
- `DOCKERHUB_TOKEN` - Docker Hub authentication token
- `GITHUB_TOKEN` - Automatically provided by GitHub Actions (no manual setup required)

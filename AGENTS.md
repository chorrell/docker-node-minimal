# AGENTS.md - Development Guide for AI Agents

## Quick Start

This repository builds minimal Node.js Docker images. To build and test locally:

```bash
# Build Node.js binary for a specific version
./build.sh -n 20.10.0

# Test the generated binary
docker build -t node-minimal .
docker run --rm node-minimal -e "console.log('Hello from Node.js ' + process.version)"
```

## Build Process

The `build.sh` script compiles Node.js from source as a static binary:

- **Usage:** `./build.sh -n NODE_VERSION`
- **Example:** `./build.sh -n 20.10.0`
- **Output:** Creates `node-v*/` directory with compiled Node.js binary
- **Configuration:** Uses `--fully-static --enable-static --without-npm --without-intl` flags
- **Duration:** Compilation takes 10-30 minutes depending on system and Node.js version

## Dockerfile

The minimal Dockerfile uses `FROM scratch` and copies only the Node.js binary:

```dockerfile
FROM scratch
COPY --link node /bin/
ENTRYPOINT ["/bin/node"]
```

## CI/CD Workflows

### dockerimage.yml

- Builds Docker images on PR changes to Dockerfile/build.sh
- Tests on both linux/amd64 and linux/arm64 platforms
- Uses ccache for faster compilation
- Automatically detects latest Node.js version

### update-current-image.yml

- Runs daily on schedule (cron: `30 0 * * *`)
- Checks for new Node.js releases
- Builds and publishes to Docker Hub and GitHub Container Registry
- Tags with version, major version, and "current"

### checkshell.yml

- Validates shell script formatting with shfmt
- Runs shellcheck for shell script linting

## Scripts

### build.sh

Compiles Node.js statically:

- Fetches GPG keys for signature verification
- Downloads Node.js source tarball and checksums
- Verifies GPG signature
- Configures with fully-static compilation flags
- Patches build files to work around static linking issues
- Compiles with optimal parallelization

### check-missing-versions.sh

Checks for new Node.js versions to build:

- Queries Node.js distribution API (nodejs.org/dist/index.json)
- Filters out known broken builds (SKIP_VERSIONS array)
- Checks Docker Hub API to find truly missing versions (does not count against pull rate limits)
- Returns newest missing version(s) sorted semantically
- Usage: `./check-missing-versions.sh -l 5` (limit to 5 versions)
- Runs in parallel for efficiency

## Code Quality

- **Linting:** shellcheck (shell script linting)
- **Formatting:** shfmt (enforces consistent shell style)
- **Pre-commit hooks:** `.pre-commit-config.yaml` enforces checks locally before commit
  - shellcheck on all `.sh` and `.bats` files
  - shfmt on all `.sh` and `.bats` files (with `-sr -i 2 -w -ci` flags)
  - markdownlint-cli2 on all `.md` files (respects `.markdownlint.yaml` config)
  - See [SETUP.md](./SETUP.md) for detailed installation instructions
  - Quick start: `pre-commit install` then hooks run automatically on commit
- **Branch Protection:** main branch requires passing checks and code owner review

## Testing

### Unit Tests

Comprehensive Bats test suite for check-missing-versions.sh:

- Run tests: `bats test/check-missing-versions.bats`
- 22 tests covering:
  - Input validation (LIMIT parameter)
  - Help/usage output
  - Script execution with various parameters
  - Output format validation (semantic versioning)
  - SKIP_VERSIONS filtering
  - Docker Hub API integration

### Integration Tests

Integration tests run in CI:

- Build Docker image with latest Node.js
- Execute JavaScript code via docker run
- Verify Node.js version output

## Dependencies

External dependencies (handled by build.sh):

- curl - downloads Node.js sources and GPG keys
- gpg - verifies GPG signatures
- tar - extracts Node.js source
- gcc/make - compiles Node.js from source
- Docker - for building and testing Docker image

## Versioning

Images are tagged with:

- Exact version: `20.10.0`
- Major version: `20`
- Latest: `latest`
- Current: `current` (always latest daily build)

Published to:

- Docker Hub: `chorrell/node-minimal:TAG`
- GitHub Container Registry: `ghcr.io/chorrell/node-minimal:TAG`

## Environment Variables

Required for publishing (GitHub Actions secrets):

- `DOCKERHUB_USERNAME` - Docker Hub username
- `DOCKERHUB_TOKEN` - Docker Hub authentication token
- `CR_PAT` - GitHub Container Registry personal access token

# Developer Setup Guide - Docker-Based Development

This guide explains how to set up the development environment for this repository using Docker. All development tools (shellcheck, shfmt, markdownlint-cli2) run in official Docker containers, requiring only Docker to be installed.

## Prerequisites

### Docker

You need Docker installed on your system. Docker provides containerized versions of all development tools, eliminating the need to install them locally.

**macOS** (Intel or Apple Silicon):

```bash
# Using Homebrew
brew install --cask docker

# Or download from https://www.docker.com/products/docker-desktop
```

**Linux** (Ubuntu/Debian):

```bash
sudo apt-get update
sudo apt-get install docker.io docker-compose
sudo usermod -aG docker $USER
newgrp docker
```

**Windows**:

Download and install [Docker Desktop for Windows](https://www.docker.com/products/docker-desktop)

Verify installation:

```bash
docker --version
```

## Quick Start

All linting commands are available via the Makefile:

```bash
# Run all linters
make lint

# Run individual linters
make shellcheck        # Check shell scripts
make shfmt             # Check shell formatting
make markdown-lint     # Check markdown files

# Auto-fix formatting issues
make format            # Auto-fixes shell scripts via shfmt
make shfmt-fix         # Explicit shfmt fix command

# See all available commands
make help
```

## Development Workflow

### Before Committing

Run all checks to ensure code quality:

```bash
make lint
```

This runs:

1. **shellcheck** - Validates shell script syntax and best practices
2. **shfmt** - Checks shell script formatting
3. **markdownlint-cli2** - Validates markdown files

Fix any issues, then commit.

### Using Pre-commit Hooks (Optional)

Pre-commit hooks automatically run checks before each commit. This requires the pre-commit framework:

```bash
pip install pre-commit
```

Install the hooks in your repository:

```bash
pre-commit install
```

Now, when you commit, hooks automatically run checks via Docker containers. If any check fails, the commit is blocked. Fix the issues and try again.

Run hooks manually on all files:

```bash
pre-commit run --all-files
```

Or use the Makefile:

```bash
make lint
```

## How It Works

### Official Docker Images

The Makefile uses official Docker images from tool maintainers:

- **mvdan/shfmt:v3** - Shell script formatter
- **koalaman/shellcheck:stable** - Shell script linter
- **node:lts-alpine** - Node.js LTS (for markdownlint-cli2)

Each tool runs in a temporary container with volume mounts for the project directory.

### Makefile

Convenient targets wrap Docker commands with proper volume mounts and working directories:

```bash
# This command:
make lint

# Runs in Docker:
docker run --rm -v $(pwd):/work -w /work mvdan/shfmt:v3 -sr -i 2 -l -ci *.sh
docker run --rm -v /mnt koalaman/shellcheck:stable *.sh
docker run --rm -v $(pwd):/work -w /work node:lts-alpine npx markdownlint-cli2 "*.md"
```

### Pre-commit Hooks with Docker

The `.pre-commit-config.yaml` configures hooks to run checks inside Docker containers. When you run `git commit`, pre-commit executes the tools via Docker for consistency.

## Troubleshooting

### Docker Image Pull Fails

**Error**: `failed to pull image`

**Solution**: Ensure Docker daemon is running and has internet access:

```bash
docker run hello-world
```

On macOS, you may need to start Docker Desktop. On Linux, restart the daemon:

```bash
sudo systemctl restart docker
```

### "make: command not found"

**Solution**: Install make:

```bash
# macOS
brew install make

# Linux (Ubuntu/Debian)
sudo apt-get install make

# Linux (Fedora/RHEL)
sudo dnf install make
```

### Permission Denied Errors

**Error**: `permission denied while trying to connect to Docker daemon`

**Solution**: Add your user to the docker group (Linux):

```bash
sudo usermod -aG docker $USER
newgrp docker
```

Then log out and back in, or run:

```bash
docker ps
```

### Pre-commit Hooks Not Running

**Error**: Hooks don't execute on commit

**Solution**: Verify installation:

```bash
# Check if installed
ls -la .git/hooks/pre-commit

# Reinstall hooks
pre-commit install

# Run manually to debug
pre-commit run --all-files
```

### "markdownlint: command not found" in Hooks

Pre-commit may cache failures. Clear and retry:

```bash
pre-commit clean
pre-commit run --all-files
```

## Why Docker?

Using Docker for development tools provides:

- **Consistency**: Same tool versions across developers and CI/CD
- **Isolation**: Tools don't interfere with system or other projects
- **Zero Installation**: Only Docker required; no brew, npm, or system package managers
- **Official Images**: Uses well-maintained images from tool authors
- **Easy Maintenance**: Update by changing version tags, not build scripts

## For AI Agents

AI agents can use the Makefile targets for automated checks:

```bash
# Run all linters
make lint

# Fix formatting issues
make format
```

Or call Docker commands directly:

```bash
docker run --rm -v "$(pwd)":/work -w /work mvdan/shfmt:v3 -sr -i 2 -l -ci *.sh
docker run --rm -v "$(pwd)":/mnt koalaman/shellcheck:stable *.sh
docker run --rm -v "$(pwd)":/work -w /work node:lts-alpine npx markdownlint-cli2 "*.md"
```

This approach requires only Docker to be installed in the agent's environment.

## For More Information

- [Docker Documentation](https://docs.docker.com/)
- [Makefile Documentation](https://www.gnu.org/software/make/manual/)
- [Pre-commit Framework](https://pre-commit.com/)
- [shellcheck](https://www.shellcheck.net/)
- [shfmt](https://github.com/mvdan/sh)
- [markdownlint-cli2](https://github.com/DavidAnson/markdownlint-cli2)

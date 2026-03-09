# Developer Setup Guide - Pre-commit Hooks

This guide explains how to set up the pre-commit hooks for this repository on macOS.

## Overview

Pre-commit hooks automatically validate your code before each commit, catching issues early and ensuring consistent code quality. This repository uses Docker-based pre-commit hooks to enforce:

- **shellcheck** - Validates shell script syntax and best practices
- **shfmt** - Auto-formats shell scripts consistently
- **markdownlint-cli2** - Enforces markdown style guidelines

These same checks also run in GitHub Actions (checkshell.yml workflow), so using pre-commit hooks locally saves time by catching issues before pushing.

## Prerequisites

Before installing pre-commit hooks, ensure you have:

- **Homebrew** - macOS package manager
- **Docker** - Required for running the linting tools in containers

## Installation Instructions

Follow these steps to set up pre-commit hooks on macOS:

### Step 1: Verify Docker is Installed

Check that Docker is running:

```bash
docker --version
docker ps
```

If Docker is not installed, download and install [Docker Desktop](https://www.docker.com/products/docker-desktop).

### Step 2: Install pre-commit Framework

Install pre-commit using Homebrew:

```bash
brew install pre-commit
```

Verify installation:

```bash
pre-commit --version
```

### Step 3: Enable Pre-commit Hooks

Navigate to the repository and install the hooks:

```bash
cd /path/to/docker-node-minimal
pre-commit install
```

You should see:

```bash
pre-commit installed at .git/hooks/pre-commit
```

### Step 4: Verify Installation

Test that all hooks work correctly:

```bash
pre-commit run --all-files
```

You should see output like:

```bash
shellcheck...Passed
shfmt........Passed
markdownlint-cli2...Passed
```

All three should pass without errors. Docker will automatically pull the required container images on first run.

## Usage

### Running Hooks Automatically

Hooks run automatically when you commit. Docker containers are launched automatically:

```bash
git commit -m "Your commit message"
```

If any hook fails, the commit is blocked. Fix the errors and commit again.

### Running Hooks Manually

Run all hooks on all files:

```bash
pre-commit run --all-files
```

Run a specific hook:

```bash
pre-commit run shellcheck --all-files
pre-commit run shfmt-docker --all-files
pre-commit run markdownlint-cli2-docker --all-files
```

Run hooks only on changed files (default behavior at commit time):

```bash
pre-commit run
```

### Updating Hook Versions

Update hooks to their latest compatible versions:

```bash
pre-commit autoupdate
```

### Temporarily Skipping Hooks

For emergency commits (not recommended), bypass hooks:

```bash
git commit --no-verify
```

## Hook Configuration

Hooks are defined in `.pre-commit-config.yaml` and run inside Docker containers. Here's what each hook does:

### shellcheck

- **Purpose**: Validates shell script syntax and style
- **Files checked**: `*.sh` and `*.bats`
- **Configuration**: Default shellcheck rules
- **Docker image**: Runs in `koalaman/shellcheck` container

Detects:

- Syntax errors
- Non-portable code
- Unsafe variable usage
- Unused variables

### shfmt

- **Purpose**: Auto-formats shell scripts
- **Files checked**: `*.sh` and `*.bats`
- **Flags**: `-sr -i 2 -w -ci`
  - `-sr`: Simplify and space-align words
  - `-i 2`: Indent with 2 spaces
  - `-w`: Write changes back to files
  - `-ci`: Indent switch cases
- **Docker image**: Runs in `mvdan/sh` container

Matches the formatting used in CI (GitHub Actions checkshell.yml).

### markdownlint-cli2

- **Purpose**: Enforces markdown style guidelines
- **Files checked**: `*.md`
- **Configuration**: Respects `.markdownlint.yaml` in repository root
- **Docker image**: Runs in `davidanson/markdownlint-cli2` container

Current settings:

- MD013 (line length) is disabled to allow longer documentation lines

## Troubleshooting

### "pre-commit: command not found"

The `pre-commit` command is not in your PATH.

**Solution**:

1. Verify installation: `brew list pre-commit`
2. If not installed: `brew install pre-commit`
3. If installed, add to PATH or reinstall:

```bash
brew uninstall pre-commit
brew install pre-commit
```

### Docker errors when running hooks

Hooks run Docker containers for linting tools. Ensure Docker is running.

**Solution**:

1. Start Docker Desktop (if using macOS)
2. Verify Docker is available: `docker ps`
3. Check if containers can be pulled: `docker pull alpine` (test)

### "Cannot connect to Docker daemon"

Docker Desktop is not running or Docker is not installed.

**Solution**:

1. Start Docker Desktop from Applications
2. Or install Docker Desktop: [https://www.docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop)

### Hooks not running after `pre-commit install`

**Solution**: Verify installation and reinstall:

```bash
# Check if installed
ls -la .git/hooks/pre-commit

# Reinstall
pre-commit install
```

### Permission denied errors

**Solution**: Check file permissions:

```bash
# Make hooks executable
chmod +x .git/hooks/pre-commit
```

### Hook modifications not taking effect

**Solution**: Hooks are cached. Clear the cache:

```bash
pre-commit clean
pre-commit run --all-files
```

### Slow first run of hooks

Docker container images are large. The first run will pull required images (shellcheck, shfmt, markdownlint-cli2), which may take a few minutes.

**Solution**: Wait for initial pull to complete. Subsequent runs will be faster as images are cached locally.

## CI/CD Integration

These same checks run in the GitHub Actions CI pipeline (`.github/workflows/checkshell.yml`):

- **shfmt** job: Validates formatting matches the configured rules
- **shellcheck** job: Validates shell scripts

Using pre-commit hooks locally ensures your changes pass CI checks before pushing.

## More Information

For more details on pre-commit framework, see the [official documentation](https://pre-commit.com/).

For specific tool documentation:

- [shellcheck](https://www.shellcheck.net/)
- [shfmt](https://github.com/mvdan/sh)
- [markdownlint-cli2](https://github.com/DavidAnson/markdownlint-cli2)

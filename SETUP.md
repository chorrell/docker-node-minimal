# Developer Setup Guide - Pre-commit Hooks

This guide explains how to set up the pre-commit hooks for this repository on macOS.

## Overview

Pre-commit hooks automatically validate your code before each commit, catching issues early and ensuring consistent code quality. This repository enforces:

- **shellcheck** - Validates shell script syntax and best practices
- **shfmt** - Auto-formats shell scripts consistently
- **markdownlint-cli2** - Enforces markdown style guidelines

These same checks also run in GitHub Actions (checkshell.yml workflow), so using pre-commit hooks locally saves time by catching issues before pushing.

## Prerequisites

Before installing pre-commit hooks, ensure you have:

- **Python 3.14+** - Required for the pre-commit framework
- **Homebrew** - macOS package manager
- **Node.js 22+ and npm** - Required for markdownlint-cli2

## Installation Instructions

Follow these steps to set up pre-commit hooks on macOS:

### Step 1: Install Homebrew (if needed)

If you don't have Homebrew installed:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Step 2: Install Required Tools via Homebrew

Install all necessary tools in one command:

```bash
brew install pre-commit shellcheck shfmt
```

This installs:

- **pre-commit 4.5.1** - Framework for managing pre-commit hooks
- **shellcheck 0.11.0** - Shell script static analysis tool
- **shfmt 3.12.0** - Shell script formatter (formats with `-sr -i 2 -w -ci` flags)

### Step 3: Install Node.js and npm (if needed)

If you don't have Node.js and npm, install via Homebrew:

```bash
brew install node
```

Alternatively, use a Node.js version manager:

```bash
# Using nvm
nvm install --lts

# Using fnm (Fast Node Manager)
fnm install --lts
```

Verify installation:

```bash
node --version
npm --version
```

### Step 4: Install markdownlint-cli2

Install the markdown linter globally via npm:

```bash
npm install -g markdownlint-cli2
```

This installs **markdownlint-cli2 v0.20.0** - Markdown file linter.

### Step 5: Enable Pre-commit Hooks

Navigate to the repository and install the hooks:

```bash
cd /path/to/docker-node-minimal
pre-commit install
```

You should see:

```bash
pre-commit installed at .git/hooks/pre-commit
```

### Step 6: Verify Installation

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

All three should pass without errors.

## Usage

### Running Hooks Automatically

Hooks run automatically when you commit:

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
pre-commit run shfmt --all-files
pre-commit run markdownlint-cli2 --all-files
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

Hooks are defined in `.pre-commit-config.yaml`. Here's what each hook does:

### shellcheck

- **Purpose**: Validates shell script syntax and style
- **Files checked**: `*.sh` and `*.bats`
- **Configuration**: Default shellcheck rules

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

Matches the formatting used in CI (GitHub Actions checkshell.yml).

### markdownlint-cli2

- **Purpose**: Enforces markdown style guidelines
- **Files checked**: `*.md`
- **Configuration**: Respects `.markdownlint.yaml` in repository root

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

### "shellcheck: command not found"

**Solution**: Install via Homebrew:

```bash
brew install shellcheck
```

### "shfmt: command not found"

**Solution**: Install via Homebrew:

```bash
brew install shfmt
```

### "markdownlint-cli2: command not found"

**Solution**: Install via npm:

```bash
npm install -g markdownlint-cli2
```

Make sure Node.js and npm are installed first.

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

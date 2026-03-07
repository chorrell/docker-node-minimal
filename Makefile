.PHONY: help lint shellcheck shfmt shfmt-fix markdown-lint format

export DOCKER_CLI_HINTS=false

help:
	@echo "Available targets:"
	@echo "  lint              Run all linters (shellcheck, shfmt, markdownlint)"
	@echo "  shellcheck        Run shellcheck"
	@echo "  shfmt             Check shell script formatting"
	@echo "  shfmt-fix         Auto-fix shell script formatting"
	@echo "  markdown-lint     Check markdown files"
	@echo "  format            Auto-format shell scripts (alias for shfmt-fix)"

shellcheck:
	docker run --rm -v "$$(pwd)":/mnt koalaman/shellcheck:stable *.sh

shfmt:
	docker run --rm -v "$$(pwd)":/work -w /work mvdan/shfmt:v3 -sr -i 2 -l -ci *.sh

shfmt-fix:
	docker run --rm -v "$$(pwd)":/work -w /work mvdan/shfmt:v3 -sr -i 2 -w -ci *.sh

markdown-lint:
	docker run --rm -v "$$(pwd)":/work -w /work node:lts-alpine sh -c "npx markdownlint-cli2 '*.md'"

format: shfmt-fix

lint: shellcheck shfmt markdown-lint

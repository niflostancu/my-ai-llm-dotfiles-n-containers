#!/bin/bash
# Repo linters. Run via `make lint` or directly: scripts/lint.sh [sh|config]
#   sh     - shellcheck -x every tracked *.sh (rules: ./.shellcheckrc)
#   config - YAML/JSON syntax of every tracked config (compose, agent configs)
#   all    - both (default)
set -euo pipefail

cd -- "$(dirname -- "$(realpath -e "${BASH_SOURCE[0]}")")/.."

usage() {
	cat <<'EOF'
usage: scripts/lint.sh [sh|config|all]
  sh     - shellcheck every tracked *.sh (rules: ./.shellcheckrc)
  config - YAML/JSON syntax of every tracked config (compose, agent configs)
  all    - both (default)
EOF
}

# NUL-separated list of tracked files matching the given globs, minus ignored subtrees
tracked() {
	git ls-files -z -- "$@" | grep -zv -e '^_experiments/'
}

lint_sh() {
	command -v shellcheck >/dev/null ||
		{ echo "lint-sh: shellcheck not found (apt install shellcheck)" >&2; return 1; }
	local files
	mapfile -d '' -t files < <(tracked '*.sh')
	((${#files[@]})) || { echo "lint-sh: no shell scripts found" >&2; return 1; }
	echo "shellcheck: ${#files[@]} file(s)"
	shellcheck -x "${files[@]}"
}

lint_config() {
	if ! command -v jq >/dev/null || ! python3 -c 'import yaml' 2>/dev/null; then
		echo "lint-config: needs jq + python3-yaml" >&2
		return 1
	fi
	local files f
	mapfile -d '' -t files < <(tracked '*.yml' '*.yaml' '*.json')
	((${#files[@]})) || return 0
	echo "config: ${#files[@]} file(s)"
	for f in "${files[@]}"; do
		case $f in
		*.json) jq -e . "$f" >/dev/null ||
			{ echo "FAIL json: $f" >&2; return 1; } ;;
		*) python3 -c 'import sys, yaml
yaml.SafeLoader.add_multi_constructor("!", lambda l, s, n: None)
yaml.safe_load(open(sys.argv[1]))' "$f" ||
			{ echo "FAIL yaml: $f" >&2; return 1; } ;;
		esac
	done
}

case "${1:-all}" in
sh) lint_sh ;;
config) lint_config ;;
all) lint_sh; lint_config ;;
-h | --help) usage ;;
*) usage >&2; exit 2 ;;
esac

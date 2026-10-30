#!/bin/bash
# Goose Agent (containerized using Docker) -- driven by base/agent-run.sh
# The agent_* vars below are read by the sourced runner (a file-wide directive
# must precede any code, hence it sits above `set`).
# shellcheck disable=SC2034
set -eo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "$(realpath -e "${BASH_SOURCE[0]}")")" &>/dev/null && pwd)
# shellcheck source=../base/agent-run.sh
source "$SCRIPT_DIR/../base/agent-run.sh"

GOOSE_AGENT_DIR=${GOOSE_AGENT_DIR:-"goose"}

agent_name=goose
agent_image=${DOCKER_GOOSE_IMAGE:-"personal/ai-ag-goose"}
agent_home="$HOME/.config/${GOOSE_AGENT_DIR}"
agent_volumes=(
	"$agent_home"
	"$HOME/.local/share/$GOOSE_AGENT_DIR"
	"$HOME/.local/state/$GOOSE_AGENT_DIR"
)
agent_env=()
agent_cmd=(goose)
agent_usage=(
	"  GOOSE_AGENT_DIR    Config dir under ~/.config (default: goose)"
	"  DOCKER_GOOSE_IMAGE Docker image to run (default: $agent_image)"
)

agent_run "$@"

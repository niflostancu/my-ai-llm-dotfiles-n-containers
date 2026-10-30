#!/bin/bash
# Customized Pi Agent (containerized using Docker) -- driven by base/agent-run.sh
# The agent_* vars below are read by the sourced runner (a file-wide directive
# must precede any code, hence it sits above `set`).
# shellcheck disable=SC2034
set -eo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "$(realpath -e "${BASH_SOURCE[0]}")")" &>/dev/null && pwd)
# shellcheck source=../base/agent-run.sh
source "$SCRIPT_DIR/../base/agent-run.sh"
# shellcheck source=../base/devcontainer/run.sh
source "$SCRIPT_DIR/../base/devcontainer/run.sh"

# variant (pi / little / omp), possibly preselected in pi-agent-default.env
PI_CFG=${PI_CFG:-"pi"}
PI_AGENT_DEF_ENV="$HOME/.config/pi-agent-default.env"
[[ ! -f "$PI_AGENT_DEF_ENV" ]] || source "$PI_AGENT_DEF_ENV"
_PI_SUFFIX=; [[ "$PI_CFG" == "pi" ]] || _PI_SUFFIX="-${PI_CFG}"

# separate config/share paths per variant
agent_name="pi${_PI_SUFFIX}"
agent_image=${DOCKER_PI_IMAGE:-"personal/ai-ag-pi${_PI_SUFFIX}"}
PI_AGENT_DIR=${PI_AGENT_DIR:-"pi-agent${_PI_SUFFIX}"}
agent_home=${PI_AGENT_HOME:-"$HOME/.config/${PI_AGENT_DIR}"}
agent_volumes=(
	"$agent_home"
	"${PI_AGENT_SHARE:-"$HOME/.local/share/${PI_AGENT_DIR}"}"
)
agent_env=("PI_CODING_AGENT_DIR=/home/agent/.config/pi-agent${_PI_SUFFIX}")
agent_usage=(
	"  PI_CFG             Config variant: pi / little / omp (default: pi)"
	"  DOCKER_PI_IMAGE    Docker image to run (default: $agent_image)"
)
case "$PI_CFG" in
little) agent_cmd=(little-coder) ;;
omp) agent_cmd=(omp) ;;
*) agent_cmd=(pi) ;;
esac

# devcontainer project support: run pi inside the project's .devcontainer image,
# built with the shared agent feature (see base/devcontainer/run.sh)
agent_setup() {
	dc_agent_setup pi "$agent_image" "$PI_CFG"
}

agent_run "$@"

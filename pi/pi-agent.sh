#!/bin/bash
# Customized Pi Agent (containerized using Docker) -- driven by base/agent-run.sh
# The agent_* vars below are read by the sourced runner (a file-wide directive
# must precede any code, hence it sits above `set`).
# shellcheck disable=SC2034
set -eo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "$(realpath -e "${BASH_SOURCE[0]}")")" &>/dev/null && pwd)
# shellcheck source=../base/agent-run.sh
source "$SCRIPT_DIR/../base/agent-run.sh"

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
	"  PI_DEVCONTAINER    Build image from .devcontainer if present (default: 1)"
)
case "$PI_CFG" in
little) agent_cmd=(little-coder) ;;
omp) agent_cmd=(omp) ;;
*) agent_cmd=(pi) ;;
esac

# devcontainer project support: if the project ships a .devcontainer config,
# build an image from it with the pi-agent feature injected and run pi from it
agent_setup() {
	[[ -f "$WORKDIR/.devcontainer/devcontainer.json" ]] || return 0
	[[ "${PI_DEVCONTAINER:-1}" == 1 ]] || return 0

	source "$SCRIPT_DIR/devcontainer/build.sh"
	agent_image="${agent_image%/*}/ai-ag-pi-$NAME"
	build_dc_image "$WORKDIR" "$agent_image"

	# devcontainer-built images don't get the feature's entrypoint baked into the
	# image metadata (it only lands in the devcontainer.metadata label), so invoke
	# the agent entrypoint explicitly (required to set UIDs + su to 'agent')
	DOCKER_ARGS+=(--entrypoint "/usr/local/bin/agent-entrypoint.sh")
	# send original project's entrypoint as env, for chain-calling
	local orig_ep
	orig_ep=$(docker image inspect --format '{{json .Config.Entrypoint}}' \
		"$agent_image" 2>/dev/null) || orig_ep=""
	if [[ -n "$orig_ep" && "$orig_ep" != "null" ]]; then
		DOCKER_ARGS+=(-e "PI_ORIG_ENTRYPOINT=$orig_ep")
	fi
	# inject runArgs/mounts from devcontainer.json
	source "$SCRIPT_DIR/devcontainer/dc-args.sh"
	dc_run_args "$WORKDIR/.devcontainer/devcontainer.json" "$WORKDIR"
}

agent_run "$@"

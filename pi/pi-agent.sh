#!/bin/bash
# Customized Pi Agent (containerized using Docker)
set -eo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "$(realpath -e "${BASH_SOURCE[0]}")")" &>/dev/null && pwd)

source "$SCRIPT_DIR/../base/docker-helpers.sh"

# also load the env containing the default PI_CFG
PI_CFG=${PI_CFG:-"pi"}
PI_AGENT_DEF_ENV="$HOME/.config/pi-agent-default.env"
[[ ! -f "$PI_AGENT_DEF_ENV" ]] || source "$PI_AGENT_DEF_ENV"
_PI_SUFFIX=; [[ "$PI_CFG" == "pi" ]] || _PI_SUFFIX="-${PI_CFG}"

# defaults
# extract relative path to use as project workdir inside container
WORKDIR=$PWD
NAME=$(get_project_name "$WORKDIR")
DOCKER_PI_IMAGE=${DOCKER_PI_IMAGE:-"personal/ai-ag-pi${_PI_SUFFIX}"}
DOCKER_USERNAME=agent
DOCKER_NET=ai-agents-net

# devcontainer project support: if the project ships a .devcontainer config,
# build an image from it with the pi-agent feature injected
DC_JSON="$WORKDIR/.devcontainer/devcontainer.json"
DC_BUILT=0
if [[ -f "$DC_JSON" && ${PI_DEVCONTAINER:-1} == 1 ]]; then
	source "$SCRIPT_DIR/devcontainer/build.sh"
	DOCKER_PI_IMAGE="${DOCKER_PI_IMAGE%/*}/ai-ag-pi-$NAME"
	build_dc_image "$WORKDIR" "$DOCKER_PI_IMAGE"
	DC_BUILT=1
fi

# use separate home config paths for the different cfg variants
PI_AGENT_DIR=${PI_AGENT_DIR:-"pi-agent${_PI_SUFFIX}"}
PI_AGENT_HOME=${PI_AGENT_HOME:-"$HOME/.config/${PI_AGENT_DIR}"}
PI_AGENT_SHARE=${PI_AGENT_SHARE:-"$HOME/.local/share/${PI_AGENT_DIR}"}
HOST_VOLUMES=(
	"$PI_AGENT_HOME"
	"$HOME/.local/share/pi-agent$_PI_SUFFIX"
)
DOCKER_ENV=${DOCKER_ENV:-"$PI_AGENT_HOME/.env"}
[ -z ${DOCKER_ARGS+x} ] || DOCKER_ARGS=()

CMD_ARGS=(pi)
SUDO=0
if [[ "$PI_CFG" == "little" ]]; then CMD_ARGS=(little-coder); fi
if [[ "$PI_CFG" == "omp" ]]; then CMD_ARGS=(omp); fi
usage() {
	cat <<EOF
Usage: pi-agent.sh [options] [args...]

Run the pi agent in a Docker container.

Options:
  --name <name>     Container/project name (default: derived from working directory)
  --cmd             Remaining arguments are the full command (default: pi)
  --volume <v>, -v  Extra Docker volume, same syntax as docker CLI (source:target[:mode])
  --sudo            Allow sudo inside the container
  --root-shell      Use the root shell
  -h, --help        Show this help

All non-flag arguments (or everything after "--") are passed to the command.

Environment:
  PI_CFG              Config variant (default: pi)
  DOCKER_PI_IMAGE     Docker image to run (default: personal/ai-ag-pi[-<PI_CFG>])
  DOCKER_ENV          Path to a docker --env-file (default: ~/.config/pi-agent[-<PI_CFG>]/.env)
  DOCKER_ARGS         Prepend extra raw docker run arguments (bash array)
  PI_DEVCONTAINER     Build image from .devcontainer if present (default: 1)
EOF
}

# parse cmd args
while [ $# -gt 0 ]; do
	case "$1" in
		-h|--help) usage; exit 0;;
		--name) NAME="$2"; shift 2;;
		--cmd) CMD_ARGS=(); shift;;
		-v|--volume) DOCKER_ARGS+=(-v "$2"); shift 2;;
		--sudo) SUDO=1; shift;;
		--root-shell) CMD_ARGS=(--root-shell); shift;;
		--|*) [[ "$1" == "--" ]] && shift; CMD_ARGS+=("$@"); break;;
	esac
done

# finally, build the docker environment
NAME="${NAME:-unknown}"
_CMDNAME="${CMD_ARGS+"${CMD_ARGS[0]}"}"
DOCKER_ARGS+=(
	-i --name "pi${_PI_SUFFIX}-$NAME-$_CMDNAME" --rm
	# run tini as PID 1 (since pi will spawn lots of children)
	--init
	# prevent accidental DoS
	--memory="4g" --cpus="4"
	--network "$DOCKER_NET"
	--add-host=host.docker.internal:host-gateway
	--workdir "$WORKDIR"
	-e "AGENT_UID=$(id -u)" -e "AGENT_GID=$(id -g)" -e "SUDO=$SUDO"
	# PI envs for completeness (i.e., devcontainer-built images)
	-e "PI_CODING_AGENT_DIR=/home/agent/.config/pi-agent${_PI_SUFFIX}"
)
if [ -t 0 ]; then DOCKER_ARGS+=(-t); fi
if [[ -f "$DOCKER_ENV" ]]; then DOCKER_ARGS+=(--env-file "$DOCKER_ENV"); fi

docker_add_volume "$WORKDIR" "$WORKDIR"
for host_vol in "${HOST_VOLUMES[@]}"; do
	# leave 2nd argument empty for auto container path
	docker_add_volume "$host_vol"
done

docker network create -d bridge \
	-o "com.docker.network.bridge.name"="d-ai-net" \
	"$DOCKER_NET" &>/dev/null || true

# DevContainer-specific docker args injection
# Processing devcontainer.json format in bash (with AI-assisted code),
# please God forgive me!
if [[ "$DC_BUILT" == 1 ]]; then
	# devcontainer-built images don't get the feature's entrypoint baked into the
	# image metadata (it's only stored in the devcontainer.metadata label), so
	# invoke the agent entrypoint explicitly (required to set UIDs + su to 'agent')
	DOCKER_ARGS+=(--entrypoint "/usr/local/bin/agent-entrypoint.sh")
	# send original project's entrypoint as env, for chain-calling
	_orig_ep=$(docker image inspect --format '{{json .Config.Entrypoint}}' \
		"${DOCKER_PI_IMAGE}" 2>/dev/null) || _orig_ep=""
	if [[ -n "$_orig_ep" && "$_orig_ep" != "null" ]]; then
		DOCKER_ARGS+=(-e "PI_ORIG_ENTRYPOINT=$_orig_ep")
	fi
	# inject runArgs/mounts from devcontainer.json into DOCKER_ARGS
	source "$SCRIPT_DIR/devcontainer/dc-args.sh"
	dc_run_args "$DC_JSON" "$WORKDIR"
fi

exec docker run "${DOCKER_ARGS[@]}" "$DOCKER_PI_IMAGE" "${CMD_ARGS[@]}"

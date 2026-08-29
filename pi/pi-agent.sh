#!/bin/bash
# Customized Pi Agent (containerized using Docker)
set -eo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

if [[ -f "$SCRIPT_DIR/../base/docker-helpers.sh" ]]; then
	source "$SCRIPT_DIR/../base/docker-helpers.sh"
else
	source "${XDG_DATA_HOME:-$HOME/.local/share}/ai-agent/lib/docker-helpers.sh"
fi

# defaults
PI_CFG=${PI_CFG:-"pi"}
NAME=${NAME:-}
CMDNAME=${CMDNAME:-DEFAULT}
CUSTOM_COMMAND=

# extract relative path to use as project workdir inside container
WORKDIR=$PWD
NAME=$(get_project_name "$WORKDIR")

DOCKER_USERNAME=agent
DOCKER_NET=ai-agents-net
HOST_VOLUMES=(
	"$HOME/.config/pi-agent$_PI_SUFFIX"
	"$HOME/.local/share/pi-agent$_PI_SUFFIX"
)
DOCKER_ARGS=()

# load user-specific environment
PI_AGENT_DEF_ENV="$HOME/.config/pi-agent-default.env"
if [[ -f "$PI_AGENT_DEF_ENV" ]]; then source "$PI_AGENT_DEF_ENV"; fi

# parse cmd args
ARGS=()
while [ $# -gt 0 ]; do
	if [[ -z "$CMDNAME" && "$1" != "-"* ]]; then CMDNAME="$1"; fi
	if [[ "$1" == "--name" ]]; then 
		NAME="$2"; shift;
	elif [[ "$1" == "--cmd" ]]; then 
		CUSTOM_COMMAND=1;
	elif [[ "$1" == "--shell" ]]; then 
		CUSTOM_COMMAND=1; DOCKER_ARGS+=(--entrypoint bash);
		CMDNAME="SHELL"
	elif [[ "$1" == "--" ]]; then
		shift; ARGS=("$@");
		if [[ -z "$CMDNAME" ]]; then CMDNAME="${ARGS[1]}"; fi
		break
	else ARGS+=("$1"); fi; shift
done
NAME="${NAME:-unknown}"

# use separate home config paths for the different cfg variants
_PI_SUFFIX=
[[ "$PI_CFG" == "pi" ]] || _PI_SUFFIX="-${PI_CFG}"
_PI_CMD=(pi)
PI_AGENT_HOME="$HOME/.config/pi-agent${_PI_SUFFIX}"
PI_AGENT_IMAGE=${PI_AGENT_IMAGE:-"personal/ai-ag-pi${_PI_SUFFIX}"}
DOCKER_ENV="$PI_AGENT_HOME/.env"
if [[ "$PI_CFG" == "little" ]]; then _PI_CMD=(little-coder); fi
if [[ "$PI_CFG" == "omp" ]]; then _PI_CMD=(omp); fi

DOCKER_ARGS+=(
	-i --name "pi${_PI_SUFFIX}-$NAME-$CMDNAME" --rm
	# run tini as PID 1 (since pi will spawn lots of children)
	--init
	# prevent accidental DoS
	--memory="4g" --cpus="4"
	--network "$DOCKER_NET"
	--add-host=host.docker.internal:host-gateway
	--workdir "$WORKDIR"
	-e "AGENT_UID=$(id -u)" -e "AGENT_GID=$(id -g)"
)
docker_add_volume "$WORKDIR" "$WORKDIR"

if [[ -f "$DOCKER_ENV" ]]; then DOCKER_ARGS+=(--env-file "$DOCKER_ENV"); fi
if [ -t 0 ]; then DOCKER_ARGS+=(-t); fi

[[ -n "$CUSTOM_COMMAND" ]] || ARGS=("${_PI_CMD[@]}" "${ARGS[@]}")

for host_vol in "${HOST_VOLUMES[@]}"; do
	# leave 2nd argument empty for auto container path
	docker_add_volume "$host_vol"
done

docker network create -d bridge \
	-o "com.docker.network.bridge.name"="d-ai-net" \
	"$DOCKER_NET" &>/dev/null || true

exec docker run "${DOCKER_ARGS[@]}" "$PI_AGENT_IMAGE" "${ARGS[@]}"

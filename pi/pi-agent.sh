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
if [[ "$PI_CFG" == "little" ]]; then CMD_ARGS=(little-coder); fi
if [[ "$PI_CFG" == "omp" ]]; then CMD_ARGS=(omp); fi
# parse cmd args
while [ $# -gt 0 ]; do
	if [[ "$1" == "--name" ]]; then
		NAME="$2"; shift;
	elif [[ "$1" == "--cmd" ]]; then
		CMD_ARGS=();
	elif [[ "$1" == "--root-shell" ]]; then
		CMD_ARGS=(--root-shell)
	else 
		if [[ "$1" == "--" ]]; then shift; fi
		CMD_ARGS+=("$@"); break
	fi
	shift
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
	-e "AGENT_UID=$(id -u)" -e "AGENT_GID=$(id -g)"
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

exec docker run "${DOCKER_ARGS[@]}" "$DOCKER_PI_IMAGE" "${CMD_ARGS[@]}"

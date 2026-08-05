#!/bin/bash
# Customized Pi Agent (containerized using Docker)
set -eo pipefail

# parse args & extract command name
NAME=""
ARGS=()
ENTER_SHELL=
DOCKER_ARGS=()
DOCKER_NET=ai-agents-net
while [ $# -gt 0 ]; do
	if [[ -z "$NAME" && "$1" != "-"* ]]; then NAME="$1"; fi
	if [[ "$1" == "--shell" ]]; then 
		ENTER_SHELL=1; DOCKER_ARGS+=(--entrypoint bash);
	else ARGS+=("$1"); fi; shift
done
NAME="${NAME:-default}"

# use separate home config paths for the different cfg variants
CMD=pi
PI_AGENT_HOME="$HOME/.config/pi-agent"
PI_AGENT_IMAGE=${PI_AGENT_IMAGE:-"personal/ai-ag-pi"}
DOCKER_ENV="$PI_AGENT_HOME/.env"

# extract relative path to use as project workdir inside container
WORKDIR=$PWD

DOCKER_ARGS+=(
	-i --name "pi-$NAME" --rm
	# run tini as PID 1 (since pi will spawn lots of children)
	--init
	# prevent accidental DoS
	--memory="4g" --cpus="4"
	--network "$DOCKER_NET"
	--add-host=host.docker.internal:host-gateway
	-v "$WORKDIR:$WORKDIR" --workdir "$WORKDIR"
	-e "AGENT_UID=$(id -u)" -e "AGENT_GID=$(id -g)"
)
if [[ -f "$DOCKER_ENV" ]]; then DOCKER_ARGS+=(--env-file "$DOCKER_ENV"); fi
if [ -t 0 ]; then DOCKER_ARGS+=(-t); fi

[[ -n "$ENTER_SHELL" ]] || ARGS=($CMD "${ARGS[@]}")

VOLUMES=(
	".config/pi-agent"
	".local/share/pi-agent"
)
exp_uids="$(id -u):$(id -g)"
for vol in "${VOLUMES[@]}"; do
	HOST_DIR="$HOME/$vol"
	mkdir -p "$HOST_DIR"
	owner="$(stat -c '%u:%g' "$HOST_DIR")"
	if [[ "$owner" != "$exp_uids" ]]; then sudo chown "$exp_uids" "$HOST_DIR"; fi
	DOCKER_ARGS+=(-v "$HOST_DIR:/home/agent/$vol")
done

docker network create -d bridge \
	-o "com.docker.network.bridge.name"="d-ai-net" \
	"$DOCKER_NET" &>/dev/null || true

exec docker run "${DOCKER_ARGS[@]}" "$PI_AGENT_IMAGE" "${ARGS[@]}"


#!/bin/bash
# Oh-My-Pi Agent (containerized using Docker)
set -eo pipefail

OMP_IMAGE=${OMP_IMAGE:-"personal/ai-ag-omp"}
ENV_FILE="$HOME/.config/omp/.env"

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

# extract relative path to use as project workdir inside container
WORKDIR=$PWD

DOCKER_ARGS+=(
	-i --name "omp-$NAME" --rm
	# run tini as PID 1 (since omp will spawn lots of children)
	--init
	# prevent accidental DoS
	--memory="4g" --cpus="4"
	--network "$DOCKER_NET"
	--add-host=host.docker.internal:host-gateway
	-v "$WORKDIR:$WORKDIR" --workdir "$WORKDIR"
	-e "AGENT_UID=$(id -u)" -e "AGENT_GID=$(id -g)"
)
if [[ -f "$ENV_FILE" ]]; then DOCKER_ARGS+=(--env-file "$ENV_FILE"); fi
if [ -t 0 ]; then DOCKER_ARGS+=(-t); fi

[[ -n "$ENTER_SHELL" ]] || ARGS=(omp "${ARGS[@]}")

VOLUMES=(
	".config/omp"
)
exp_uids="$(id -u):$(id -g)"
for vol in "${VOLUMES[@]}"; do
	mkdir -p "$HOME/$vol"
	owner="$(stat -c '%u:%g' "$HOME/$vol")"
	if [[ "$owner" != "$exp_uids" ]]; then sudo chown "$exp_uids" "$HOME/$vol"; fi
	DOCKER_ARGS+=(-v "$HOME/$vol:/home/agent/$vol")
done

docker network create -d bridge \
	-o "com.docker.network.bridge.name"="d-ai-net" \
	"$DOCKER_NET" &>/dev/null || true

exec docker run "${DOCKER_ARGS[@]}" "$OMP_IMAGE" "${ARGS[@]}"


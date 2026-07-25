#!/bin/bash
# Goose Agent (containerized using Docker)
set -eo pipefail

GOOSE_IMAGE="personal/ai-goose"
ENV_FILE="$HOME/.config/.secure/goose.env"

# parse args & extract command name
NAME=""
ARGS=()
DOCKER_ARGS=()
while [ $# -gt 0 ]; do
	if [[ -z "$NAME" && "$1" != "-"* ]]; then NAME="$1"; fi
	if [[ "$1" == "--shell" ]]; then 
		DOCKER_ARGS+=(--entrypoint bash);
	else ARGS+=("$1"); fi; shift
done
NAME="${NAME:-default}"

# extract relative path to use as project workdir inside container
WORKDIR=$PWD

DOCKER_ARGS+=(
	-i --name "goose-$NAME" --rm
	# run tini as PID 1 (since goose will spawn lots of children)
	--init
	# prevent accidental DoS
	--memory="4g" --cpus="4"
	--network "ai-agents-net"
	-v "$WORKDIR:$WORKDIR" --workdir "$WORKDIR"
	-u "$(id -u):$(id -g)"
)
if [[ -f "$ENV_FILE" ]]; then DOCKER_ARGS+=(--env-file "$ENV_FILE"); fi
if [ -t 0 ]; then DOCKER_ARGS+=(-t); fi

VOLUMES=(
	".config/goose"
	".local/share/goose"
	".local/state/goose"
)
exp_uids="$(id -u):$(id -g)"
for vol in "${VOLUMES[@]}"; do
	mkdir -p "$HOME/$vol"
	owner="$(stat -c '%u:%g' "$HOME/$vol")"
	if [[ "$owner" != "$exp_uids" ]]; then sudo chown "$exp_uids" "$HOME/$vol"; fi
	DOCKER_ARGS+=(-v "$HOME/$vol:/home/goose/$vol")
done

exec docker run "${DOCKER_ARGS[@]}" "$GOOSE_IMAGE" "${ARGS[@]}"


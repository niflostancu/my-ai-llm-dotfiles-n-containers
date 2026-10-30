#!/bin/bash
# Shared container driver for agent CLIs (pi, goose, claude, opencode, ...).
# Sourced by the per-harness wrappers; not meant to be run directly.
#
# A wrapper sets these vars and ends with `agent_run "$@"`:
#   agent_name     container-name prefix + name used in help   (required)
#   agent_image    image to run                                (required)
#   agent_cmd      array, default command                      (required)
#   agent_home     config dir; default location of the env-file (required)
#   agent_volumes  array, host dirs mounted at the same path in the container
#   agent_env      array, extra `-e VAR=value` pairs
#   agent_usage    array, extra help lines (one per line)
#
# Optional hook, called after the project name is derived (WORKDIR/NAME are
# global) and before argument parsing:
#   agent_setup()  e.g. build a project image, adjust agent_image/DOCKER_ARGS
#
# Caller-provided DOCKER_ARGS are honored (raw leading `docker run` args).

# the wrapper assigns these (see the header above); they are not local to this file
# shellcheck disable=SC2154
_agent_run_dir=$(cd -- "$(dirname -- "$(realpath -e "${BASH_SOURCE[0]}")")" && pwd)
source "$_agent_run_dir/docker-helpers.sh"

AGENT_NET=${AGENT_NET:-ai-agents-net}
AGENT_MEMORY=${AGENT_MEMORY:-4g}
AGENT_CPUS=${AGENT_CPUS:-4}
AGENT_BRIDGE=d-ai-net

agent_usage_() {
	cat <<EOF
Usage: $(basename "$0") [options] [args...]

Run ${agent_name} in a Docker container.

Options:
  --name <name>      Container/project name (default: derived from working directory)
  --cmd              Remaining arguments are the full command (default: ${agent_cmd[0]:-})
  -v, --volume <v>   Extra Docker volume, same syntax as docker CLI (source:target[:mode])
  --sudo             Allow sudo inside the container
  --root-shell       Use the root shell
  -h, --help         Show this help

All non-flag arguments (or everything after "--") are passed to the command.

Environment:
  DOCKER_ENV         Path to a docker --env-file (default: ${DOCKER_ENV:-"$agent_home/.env"})
  DOCKER_ARGS        Prepend extra raw docker run arguments (bash array)
  AGENT_NET          Docker network (default: $AGENT_NET)
  AGENT_MEMORY       Docker memory limit (default: $AGENT_MEMORY)
  AGENT_CPUS         Docker CPU limit (default: $AGENT_CPUS)
  AGENT_DEVCONTAINER Build image from .devcontainer if present (default: 1)
EOF
	if ((${#agent_usage[@]})); then printf '%s\n' "${agent_usage[@]}"; fi
}

agent_run() {
	local cmd_args=("${agent_cmd[@]}") cmd_name e v

	# project name from the working directory (falls back to a fixed name when
	# the project lives outside $HOME, where get_project_name gives up)
	WORKDIR=$PWD
	NAME=$(get_project_name "$WORKDIR") || NAME=unknown

	SUDO=0
	DOCKER_ENV=${DOCKER_ENV:-"$agent_home/.env"}
	# initialize only when unset: caller-provided DOCKER_ARGS are kept and lead
	if [ -z "${DOCKER_ARGS+x}" ]; then DOCKER_ARGS=(); fi

	if declare -F agent_setup >/dev/null; then agent_setup; fi

	while [ $# -gt 0 ]; do
		case "$1" in
		-h | --help) agent_usage_; exit 0 ;;
		--name) NAME="$2"; shift 2 ;;
		--cmd) cmd_args=(); shift ;;
		-v | --volume) DOCKER_ARGS+=(-v "$2"); shift 2 ;;
		--sudo) SUDO=1; shift ;;
		--root-shell) cmd_args=(--root-shell); shift ;;
		-- | *)
			[[ "$1" != "--" ]] || shift
			cmd_args+=("$@")
			break
			;;
		esac
	done

	cmd_name=${cmd_args[0]:-unknown}
	DOCKER_ARGS+=(
		-i --name "${agent_name}-${NAME}-${cmd_name}" --rm
		# run tini as PID 1 (agents spawn lots of children)
		--init
		# prevent accidental DoS
		--memory="$AGENT_MEMORY" --cpus="$AGENT_CPUS"
		--network "$AGENT_NET"
		--add-host=host.docker.internal:host-gateway
		--workdir "$WORKDIR"
		-e "AGENT_UID=$(id -u)" -e "AGENT_GID=$(id -g)" -e "SUDO=$SUDO"
	)
	for e in "${agent_env[@]}"; do DOCKER_ARGS+=(-e "$e"); done
	if [ -t 0 ]; then DOCKER_ARGS+=(-t); fi
	if [[ -f "$DOCKER_ENV" ]]; then DOCKER_ARGS+=(--env-file "$DOCKER_ENV"); fi

	docker_add_volume "$WORKDIR" "$WORKDIR"
	for v in "${agent_volumes[@]}"; do
		# leave 2nd argument empty for auto container path (~ -> /home/agent)
		docker_add_volume "$v"
	done

	docker network create -d bridge \
		-o "com.docker.network.bridge.name"="$AGENT_BRIDGE" \
		"$AGENT_NET" &>/dev/null || true

	exec docker run "${DOCKER_ARGS[@]}" "$agent_image" "${cmd_args[@]}"
}

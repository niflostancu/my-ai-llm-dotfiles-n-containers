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
	CMD_ARGS=("/usr/local/bin/agent-entrypoint.sh" "${CMD_ARGS[@]}")

	# expand devcontainer.json variables (https://containers.dev/implementors/json_reference/):
	# ${localEnv:NAME}, ${env:NAME}, ${containerEnv:NAME} (each with optional :default),
	# ${localWorkspaceFolder(Basename)}, ${containerWorkspaceFolder(Basename)}, ${containerUserHomeFolder}
	_dc_clean=$(sed '/^[[:space:]]*\/\//d' "$DC_JSON")
	_dc_expand() {
		local s=$1 k rest name def v;
		while [[ $s =~ \$\{([A-Za-z_][A-Za-z0-9_]*)(:([^}]*))?\} ]]; do
			k=${BASH_REMATCH[1]}; rest=${BASH_REMATCH[3]-}
			case $k in
				localEnv|env)
					if [[ $rest == *":"* ]]; then
						name=${rest%%:*}; def=${rest#*:}
						v=${!name}; [[ -n $v ]] || v=$def
					else v=${!rest-}; fi ;;
				containerEnv)
					v=$(jq -r --arg k "${rest%%:*}" '.containerEnv[$k] // empty' <<<"$_dc_clean")
					[[ -n $v || $rest != *":"* ]] || v=${rest#*:} ;;
				localWorkspaceFolder|containerWorkspaceFolder) v=$WORKDIR ;;
				localWorkspaceFolderBasename|containerWorkspaceFolderBasename) v=$(basename "$WORKDIR") ;;
				containerUserHomeFolder) v=/home/agent ;;
				*) v= ;;   # unknown (e.g. ${secret:...}): leave empty
			esac
			if [[ $v == *"\${$k"* ]]; then v=; fi   # no recursive expansion
			s=${s/"\${$k${rest:+:$rest}}"/$v}
		done
		printf '%s' "$s"
	}
	# honor devcontainer runArgs (e.g. --device /dev/kvm), variables expanded
	while IFS= read -r a; do DOCKER_ARGS+=("$(_dc_expand "$a")"); done < <(jq -r '.runArgs[]?' <<<"$_dc_clean")
	# mounts: "source=...,target=...,type=bind|volume" (keys in any order)
	while IFS=$'\t' read -r src tgt typ; do
		[[ -n "$src" ]] || continue
		src=$(_dc_expand "$src"); tgt=$(_dc_expand "$tgt")
		if [[ "$typ" == volume ]]; then
			DOCKER_ARGS+=(--mount "type=volume,source=$src,target=$tgt")
		else
			# bind: ~ → host $HOME (source) / container home (target), relative source → workdir
			src=${src/#\~/$HOME}
			[[ "$src" != /* ]] && src="$WORKDIR/$src"
			tgt=${tgt/#\~//home/agent}
			DOCKER_ARGS+=(-v "$src:$tgt")
			echo "ADD MOUNT: $src:$tgt"
		fi
	done < <(jq -r '.mounts[]? | (split(",") | map(capture("^(?<k>[^=]+)=(?<v>.*)$")) |
		map({key:.k, value:.v}) | from_entries) as $m |
		[$m.source, $m.target, ($m.type // "bind")] | @tsv' <<<"$_dc_clean")
fi

exec docker run "${DOCKER_ARGS[@]}" "$DOCKER_PI_IMAGE" "${CMD_ARGS[@]}"

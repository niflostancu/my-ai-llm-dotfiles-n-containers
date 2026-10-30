#!/bin/bash
# Devcontainer support, shared by every harness wrapper.
#
#   dc_agent_setup <harness> <image> [variant]
#
# If the current project ships .devcontainer/devcontainer.json, build that image
# with the shared agent feature injected (harness CLI + MCP addons) and point the
# run at it. Uses WORKDIR/NAME from agent_run(); sets agent_image and appends the
# devcontainer's runArgs/mounts to DOCKER_ARGS. AGENT_DEVCONTAINER=0 opts out.
#
# Adding a harness: create <harness>/devcontainer/harness.sh defining
# install_harness(), then call dc_agent_setup <harness> "$agent_image" from its
# agent_setup() hook (see pi/pi-agent.sh).

# WORKDIR/NAME come from agent_run(); agent_image is set here for the caller
# shellcheck disable=SC2153,SC2034
_dc_dir=$(cd -- "$(dirname -- "$(realpath -e "${BASH_SOURCE[0]}")")" && pwd)
_dc_root=$(cd -- "$_dc_dir/../.." && pwd)

dc_cli() {
	if command -v devcontainer >/dev/null 2>&1; then
		devcontainer "$@"
	elif command -v npx >/dev/null 2>&1; then
		npx -y @devcontainers/cli "$@"
	else
		echo "devcontainer: need the 'devcontainer' CLI (or node/npx)" >&2
		return 1
	fi
}

# expands devcontainer.json variables (https://containers.dev/implementors/json_reference/):
# ${localEnv:NAME}, ${env:NAME}, ${containerEnv:NAME} (each with optional :default),
# ${localWorkspaceFolder(Basename)}, ${containerWorkspaceFolder(Basename)}, ${containerUserHomeFolder}
dc_expand() {
	local s=$1 dc_clean=$2 workdir=$3 k rest name def v
	while [[ $s =~ \$\{([A-Za-z_][A-Za-z0-9_]*)(:([^}]*))?\} ]]; do
		k=${BASH_REMATCH[1]}; rest=${BASH_REMATCH[3]-}
		case $k in
			localEnv|env)
				if [[ $rest == *":"* ]]; then
					name=${rest%%:*}; def=${rest#*:}
					v=${!name}; [[ -n $v ]] || v=$def
				else v=${!rest-}; fi ;;
			containerEnv)
				v=$(jq -r --arg k "${rest%%:*}" '.containerEnv[$k] // empty' <<<"$dc_clean")
				[[ -n $v || $rest != *":"* ]] || v=${rest#*:} ;;
			localWorkspaceFolder|containerWorkspaceFolder) v=$workdir ;;
			localWorkspaceFolderBasename|containerWorkspaceFolderBasename) v=$(basename "$workdir") ;;
			containerUserHomeFolder) v=/home/agent ;;
			*) v= ;;   # unknown (e.g. ${secret:...}): leave empty
		esac
		if [[ $v == *"\${$k"* ]]; then v=; fi   # no recursive expansion
		s=${s/"\${$k${rest:+:$rest}}"/$v}
	done
	printf '%s' "$s"
}

# dc_run_args <dc-json> <workdir> — appends runArgs/mounts to DOCKER_ARGS
dc_run_args() {
	local dc_json=$1 workdir=$2
	local dc_clean src tgt typ a
	dc_clean=$(sed '/^[[:space:]]*\/\//d' "$dc_json")

	# honor devcontainer runArgs (e.g. --device /dev/kvm), variables expanded
	while IFS= read -r a; do DOCKER_ARGS+=("$(dc_expand "$a" "$dc_clean" "$workdir")"); done \
		< <(jq -r '.runArgs[]?' <<<"$dc_clean")
	# mounts: "source=...,target=...,type=bind|volume" (keys in any order)
	while IFS=$'\t' read -r src tgt typ; do
		[[ -n "$src" ]] || continue
		src=$(dc_expand "$src" "$dc_clean" "$workdir"); tgt=$(dc_expand "$tgt" "$dc_clean" "$workdir")
		if [[ "$typ" == volume ]]; then
			DOCKER_ARGS+=(--mount "type=volume,source=$src,target=$tgt")
		else
			# bind: ~ → host $HOME (source) / container home (target), relative source → workdir
			src=${src/#\~/$HOME}
			[[ "$src" != /* ]] && src="$workdir/$src"
			tgt=${tgt/#\~//home/agent}
			DOCKER_ARGS+=(-v "$src:$tgt")
		fi
	done < <(jq -r '.mounts[]? | (split(",") | map(capture("^(?<k>[^=]+)=(?<v>.*)$")) |
		map({key:.k, value:.v}) | from_entries) as $m |
		[$m.source, $m.target, ($m.type // "bind")] | @tsv' <<<"$dc_clean")
}

# dc_build_image <workdir> <image> <variant> <harness>
dc_build_image() {
	local workdir=$1 image=$2 variant=$3 harness=$4
	local stage feat dc_json
	local cache="${XDG_CACHE_HOME:-$HOME/.cache}/ai-agent"
	mkdir -p "$cache"
	# per-harness stage dir: dir name prefix + sha256 of the absolute path
	stage="$cache/$harness-$(basename "$workdir")-$(printf '%s' "$workdir" |
		sha256sum | cut -c1-10)"

	# stage the whole workspace dir (since it may get used in building the container)
	rsync -a "$workdir/" "$stage/"

	# stage the feature context: shared feature + this harness' installer + helpers
	feat="$stage/.devcontainer/agent"
	mkdir -p "$feat/mcp-addons" "$feat/scripts"
	rsync -a "$_dc_dir/feature/" "$feat/"
	rsync -a "$_dc_dir/../scripts/" "$feat/scripts/"
	cp "$_dc_root/$harness/devcontainer/harness.sh" "$feat/harness.sh"
	for d in "$_dc_root"/mcp-servers/*/; do
		d="${d%/}"
		[[ -f "$d/install.sh" ]] && rsync -a "$d" "$feat/mcp-addons/"
	done

	# (yep, strip JSONC comments from devcontainer.json, if any)
	dc_json=$(sed '/^[[:space:]]*\/\//d' "$workdir/.devcontainer/devcontainer.json")

	# merge project config + agent feature into the staging dir
	jq --arg variant "$variant" \
		'.features = ((.features // {}) + {"./agent": {variant: $variant}})' \
		<<<"$dc_json" > "$stage/.devcontainer/devcontainer.json"

	# build (docker layer cache makes rebuilds of unchanged configs cheap)
	dc_cli build --workspace-folder "$stage" --image-name "$image"
}

dc_agent_setup() {
	local harness=$1 image=$2 variant=${3:-$1}
	local dc_json="$WORKDIR/.devcontainer/devcontainer.json"

	[[ -f "$dc_json" ]] || return 0
	[[ "${AGENT_DEVCONTAINER:-${PI_DEVCONTAINER:-1}}" == 1 ]] || return 0
	if [[ ! -f "$_dc_root/$harness/devcontainer/harness.sh" ]]; then
		echo "devcontainer: no $harness/devcontainer/harness.sh, using $image" >&2
		return 0
	fi

	image="${image%/*}/ai-ag-$harness-$NAME"
	dc_build_image "$WORKDIR" "$image" "$variant" "$harness"

	# devcontainer-built images don't get the feature's entrypoint baked into the
	# image metadata (it only lands in the devcontainer.metadata label), so invoke
	# the agent entrypoint explicitly (required to set UIDs + su to 'agent'), and
	# forward the project's own entrypoint for chain-calling
	DOCKER_ARGS+=(--entrypoint /usr/local/bin/agent-entrypoint.sh)
	local orig_ep
	orig_ep=$(docker image inspect --format '{{json .Config.Entrypoint}}' \
		"$image" 2>/dev/null) || orig_ep=""
	if [[ -n "$orig_ep" && "$orig_ep" != "null" ]]; then
		DOCKER_ARGS+=(-e "AGENT_ORIG_ENTRYPOINT=$orig_ep")
	fi

	# inject runArgs/mounts from devcontainer.json
	dc_run_args "$dc_json" "$WORKDIR"

	agent_image=$image
}

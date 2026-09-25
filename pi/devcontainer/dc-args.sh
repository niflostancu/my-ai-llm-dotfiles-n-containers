#!/bin/bash
# devcontainer.json parsing for docker run (sourced; companion to build.sh).
# dc_run_args <dc-json> <workdir> — appends runArgs/mounts to global DOCKER_ARGS
set -eo pipefail

# expands devcontainer.json variables (https://containers.dev/implementors/json_reference/):
# ${localEnv:NAME}, ${env:NAME}, ${containerEnv:NAME} (each with optional :default),
# ${localWorkspaceFolder(Basename)}, ${containerWorkspaceFolder(Basename)}, ${containerUserHomeFolder}
dc_expand() {
	local s=$1 k rest name def v
	local dc_clean="$2"
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

dc_run_args() {
	local dc_json=$1 workdir=$2
	local dc_clean src tgt typ a
	dc_clean=$(sed '/^[[:space:]]*\/\//d' "$dc_json")

	# honor devcontainer runArgs (e.g. --device /dev/kvm), variables expanded
	while IFS= read -r a; do DOCKER_ARGS+=("$(dc_expand "$a" "$dc_clean")"); done \
		< <(jq -r '.runArgs[]?' <<<"$dc_clean")
	# mounts: "source=...,target=...,type=bind|volume" (keys in any order)
	while IFS=$'\t' read -r src tgt typ; do
		[[ -n "$src" ]] || continue
		src=$(dc_expand "$src" "$dc_clean"); tgt=$(dc_expand "$tgt" "$dc_clean")
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

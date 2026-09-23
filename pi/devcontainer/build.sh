#!/bin/bash
# Devcontainer support for pi-agent.sh.
# Builds a project image from its .devcontainer/devcontainer.json with the
# pi-agent feature injected, then pi-agent.sh runs pi from that image.
# Sourced by pi-agent.sh; usage: build_dc_image <workdir> <image-name>
set -eo pipefail

dc_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
dc_repo_root="$(cd -- "$dc_dir/../.." && pwd)"

# devcontainer staging path
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

dc_cli() {
	if command -v devcontainer >/dev/null 2>&1; then
		devcontainer "$@"
	elif command -v npx >/dev/null 2>&1; then
		npx -y @devcontainers/cli "$@"
	else
		echo "pi-agent: need 'devcontainer' CLI (or node/npx) for devcontainer builds" >&2
		return 1
	fi
}

build_dc_image() {
	local workdir=$1 image=$2
	local stage feat
	mkdir -p "$XDG_CACHE_HOME/ai-agent/"
	stage=$(mktemp -d "${XDG_CACHE_HOME}/ai-agent/$(basename "$workdir")-tmp.XXXXXX")
	#trap 'rm -rf "$stage"' EXIT

	# stage the pi feature context (shared sources, no duplication)
	feat="$stage/.devcontainer/pi-agent"
	mkdir -p "$feat/mcp-addons"
	rsync -a --exclude=devcontainer.json "$workdir/.devcontainer/" "$stage/.devcontainer/"
	cp -r "$dc_dir/feature/." "$feat/"
	for d in "$dc_repo_root"/mcp-servers/*/; do
		[[ -f "$d/install.sh" ]] && cp -r "$d" "$feat/mcp-addons/"
	done
	cp -r "$dc_repo_root/base/scripts" "$feat/scripts"

	# merge project config + pi feature; absolutize relative paths
	jq --arg proj "$workdir/.devcontainer" --arg variant "${PI_CFG:-pi}" '
		.features = ((.features // {})
			| with_entries(if .value.path? then
					.value.path = (if (.value.path | startswith("/"))
						then .value.path
						else ($proj + "/" + (.value.path | ltrimstr("./")))
						end)
				else . end)
			+ {"./pi-agent": {"variant": $variant}})
		| if .build then
			.build.context = (if (.build.context // "." | startswith("/"))
				then (.build.context // ".")
				else ($proj + "/" + (.build.context // "."))
				end)
			| if .build.dockerfile? then
				.build.dockerfile = (if (.build.dockerfile | startswith("/"))
					then .build.dockerfile
					else ($proj + "/" + .build.dockerfile)
					end)
			  else . end
		  else . end' \
		<(sed '/^[[:space:]]*\/\//d' "$workdir/.devcontainer/devcontainer.json") \
		> "$stage/.devcontainer/devcontainer.json"
	# (yep, strip JSONC comments from devcontainer.json, if any)

	# build (docker layer cache makes rebuilds of unchanged configs cheap)
	dc_cli build --workspace-folder "$stage" --image-name "$image"
}

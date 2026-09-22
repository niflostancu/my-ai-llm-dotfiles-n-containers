#!/bin/bash
# pi-agent devcontainer feature — installs pi (+ variants) and personal MCP
# servers into a Debian-based image. Runs as root at image build time,
# working dir = feature context (staged by pi/devcontainer/build.sh:
#   mcp/    <- mcp-servers/* (shared install scripts)
#   scripts <- base/scripts  (shared agent entrypoint)
set -euo pipefail

echo "[pi-agent feature] installing (variant: ${VARIANT:-pi})"

# install base layer (when not using the compatible Docker image)
if [[ -z "${AGENT_BASE_INSTALLED:-}" ]]; then
	# go is needed by the ketch mcp server
	export INSTALL_GO=1
	bash scripts/install-base.sh minimal
	cp scripts/ct-set-agent-uid.sh scripts/entrypoint-base.sh /usr/local/bin/
	ln -sf /usr/local/bin/entrypoint-base.sh /usr/local/bin/agent-entrypoint.sh
fi

# pi variant selection
case "${VARIANT:-pi}" in
pi)     BUN_INSTALL=/usr/local bun install -g --ignore-scripts \
		@earendil-works/pi-coding-agent pi-acp ;;
little) BUN_INSTALL=/usr/local bun install -g little-coder ;;
omp)    curl -fsSL https://omp.sh/install \
		| PI_INSTALL_DIR=/usr/local/bin sh -s -- --binary ;;
*) echo "[pi-agent feature] unknown variant: $VARIANT" >&2; exit 1 ;;
esac

# personal MCP servers (their install scripts run as root, gosu to agent)
for d in mcp-addons/*/; do
	[ -f "$d/install.sh" ] || continue
	echo "[pi-agent feature] MCP/tool addon: ${d%/}"
	(cd "$d" && ./install.sh)
done

echo "[pi-agent feature] done"

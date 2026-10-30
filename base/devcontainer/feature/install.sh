#!/bin/bash
# Shared devcontainer feature: installs an agent harness CLI + the personal MCP
# servers into a Debian-based image. Runs as root at image build time, with the
# working dir = the staged feature context:
#   harness.sh   <- define install_harness() (provided by <harness>/devcontainer/)
#   scripts/     <- base/scripts (base layer install + agent entrypoint)
#   mcp-addons/  <- mcp-servers/* (their own install.sh scripts)
set -euo pipefail

echo "[agent feature] installing (variant: ${VARIANT:-})"

# install the base layer (when not building on top of a compatible agent image)
if [[ -z "${AGENT_BASE_INSTALLED:-}" ]]; then
	bash scripts/install-base.sh minimal
	cp scripts/ct-set-agent-uid.sh scripts/entrypoint-base.sh /usr/local/bin/
	ln -sf /usr/local/bin/entrypoint-base.sh /usr/local/bin/agent-entrypoint.sh
fi

[[ -f harness.sh ]] || {
	echo "[agent feature] harness.sh missing (see base/devcontainer/feature/)" >&2
	exit 1
}
# shellcheck source=/dev/null
. ./harness.sh
install_harness

# personal MCP servers (their install scripts run as root, gosu to agent)
for d in mcp-addons/*/; do
	[ -f "$d/install.sh" ] || continue
	echo "[agent feature] MCP/tool addon: ${d%/}"
	(cd "$d" && ./install.sh)
done

echo "[agent feature] done"

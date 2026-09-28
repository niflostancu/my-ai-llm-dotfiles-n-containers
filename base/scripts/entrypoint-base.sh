#!/bin/bash
set -e

. /usr/local/bin/ct-set-agent-uid.sh

if [ "$1" = "--root-shell" ]; then
	exec /usr/bin/bash
fi
# chain the devcontainer image's original entrypoint (if any)
if [ -n "${PI_ORIG_ENTRYPOINT:-}" ] && [ "$PI_ORIG_ENTRYPOINT" != "null" ]; then
	# yeah, it's the JSON as originally extracted by `docker image inspect`
	mapfile -t ORIG_ENTRY < <(jq -r '.[]' <<<"$PI_ORIG_ENTRYPOINT")
	exec "${ORIG_ENTRY[@]}" gosu "${AGENT_USER:-agent}" "$@"
fi
exec gosu "${AGENT_USER:-agent}" "$@"

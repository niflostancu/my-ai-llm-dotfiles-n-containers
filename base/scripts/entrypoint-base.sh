#!/bin/sh
set -e

. /usr/local/bin/ct-set-agent-uid.sh

if [ "$1" = "--root-shell" ]; then
	exec /usr/bin/bash
fi
exec gosu "${AGENT_USER:-agent}" "$@"


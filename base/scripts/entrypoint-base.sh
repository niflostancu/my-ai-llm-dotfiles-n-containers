#!/bin/sh
set -e

ct-set-agent-uid.sh

if [ "$1" = "--root-shell" ]; then
	exec /usr/bin/bash
fi
exec gosu agent "$@"


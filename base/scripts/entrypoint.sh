#!/bin/sh
set -e

if [ -n "$AGENT_UID" ]; then
	# ensure group defaults
	AGENT_GID=${AGENT_GID:-"$AGENT_UID"}

	if [ -n "$DEBUG" ]; then
		echo "Adjusting 'agent' user: UID=$AGENT_UID, GID=$AGENT_GID" >&2
	fi

	groupmod -g "$AGENT_GID" ai-agents
	usermod -u "$AGENT_UID" agent

	# fix ownership of home
	chown -R "${AGENT_UID}:${AGENT_GID}" /home/agent
fi

exec gosu agent "$@"


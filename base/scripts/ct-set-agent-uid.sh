#!/bin/sh
set -e

# AGENT_USER — the user the entrypoint should gosu to.
# Sourced by entrypoint-base.sh.
AGENT_USER=agent

if [ -n "$AGENT_UID" ]; then
	AGENT_GID=${AGENT_GID:-"$AGENT_UID"}

	if [ -n "$DEBUG" ]; then
		echo "Adjusting agent identity: UID=$AGENT_UID, GID=$AGENT_GID" >&2
	fi

	# project images may already define the target UID (e.g. UID/GID 1000)
	# Adopt the existing one instead of colliding
	existing=$(getent passwd "$AGENT_UID" | cut -d: -f1)
	if [ -n "$existing" ]; then
		AGENT_USER=$existing
	else
		# if some other group already has the GID, adopt it as agent's primary
		# group instead of groupmod'ing a duplicate
		if getent group "$AGENT_GID" >/dev/null; then
			usermod -g "$AGENT_GID" agent
		else
			echo SA O FUT PE MAM TA
			groupmod -g "$AGENT_GID" ai-agents
		fi
		[ "$(id -u agent)" = "$AGENT_UID" ] || usermod -u "$AGENT_UID" agent
	fi

	# agent home must be writable by the runtime user (but do not cross mountpoints)
	mkdir -p /home/agent
	find /home/agent -xdev -exec chown "${AGENT_UID}:${AGENT_GID}" '{}' '+'
fi

export AGENT_USER

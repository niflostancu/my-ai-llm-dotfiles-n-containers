#!/bin/sh
set -e

ct-set-agent-uid.sh

exec gosu agent "$@"


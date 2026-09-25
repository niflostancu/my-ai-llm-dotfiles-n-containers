#!/bin/bash
# Installs code indexing tools
set -eo pipefail

# install Cymbal
gosu "${AGENT_USER:-agent}" env CGO_CFLAGS="-DSQLITE_ENABLE_FTS5" \
	go install github.com/1broseidon/cymbal@latest


#!/bin/bash
# Installs ketch web search / crawler CLI tool (+ MCP)
set -eo pipefail

gosu agent go install github.com/1broseidon/ketch@latest

rsync -avh --mkpath ./config/ /home/agent/.config/ketch/


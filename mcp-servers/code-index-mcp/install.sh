#!/bin/bash
# Installs the code-index-mcp server (use inside containers)
set -eo pipefail

gosu agent uv tool install code-index-mcp


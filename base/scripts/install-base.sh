#!/bin/bash
# Shared base deps installer for AI agent containers (Debian-based, root).
# Used by base/Dockerfile.base (full) and the pi devcontainer feature (minimal).
#   usage: install-base.sh [full|minimal]
#   env:   INSTALL_GO=1 -> install golang toolchain
set -euo pipefail
PROFILE="${1:-minimal}"

command -v apt-get >/dev/null 2>&1 || {
	echo "install-base: requires a Debian-based system (apt-get not found)" >&2
	exit 1
}

# create the unprivileged agent user (idempotent, matches the base image)
if ! id agent >/dev/null 2>&1; then
	groupadd -g 1234 ai-agents
	useradd -m -u 1234 -g ai-agents agent
fi

MINIMAL_PACKAGES=(
	bash gosu rsync ca-certificates curl wget git python3 python3-pip
	# build tools required for cgo / treesitter-based tools
	build-essential make
	# Linux CLI tools (used as agent tools)
	ripgrep fd-find bat jq zip unzip xz-utils tree file locales
)
FULL_PACKAGES=(
	"${MINIMAL_PACKAGES[@]}"
	# Common networking utils
	iputils-ping iproute2 netcat-openbsd gnupg build-essential make cmake
	# some more development tools
	python3 python3-pip libssl3 htop less vim-nox neovim openssh-client man-db
)
 
export DEBIAN_FRONTEND=noninteractive
apt-get update

case "$PROFILE" in
full)
	apt-get install -y "${FULL_PACKAGES[@]}" ;;
minimal)
	apt-get install -y --no-install-recommends "${MINIMAL_PACKAGES[@]}"
	;;
*) echo "install-base: unknown profile: $PROFILE" >&2; exit 1 ;;
esac

localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
# Debian ships these under renamed names to avoid conflicts with other tools...
[[ ! -f /usr/bin/batcat ]] || ln -sf /usr/bin/batcat /usr/local/bin/bat
[[ ! -f /usr/bin/fdfind ]] || ln -sf /usr/bin/fdfind /usr/local/bin/fd

# Node.js from APT repository + Bun
if ! command -v bun; then
	curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
	apt-get update
	apt-get install -y nodejs
	npm install -g bun
fi

# uv (static binary to /usr/local/bin)
if ! command -v uv; then
	case "$(uname -m)" in
	x86_64)  UV_ARCH=x86_64 ;;
	aarch64) UV_ARCH=aarch64 ;;
	*) echo "install-base: unsupported arch: $(uname -m)" >&2; exit 1 ;;
	esac
	curl -fsSL "https://github.com/astral-sh/uv/releases/latest/download/uv-${UV_ARCH}-unknown-linux-gnu.tar.gz" | \
		tar -xz --strip-components=1 -C /usr/local/bin
fi

# golang (fetch latest stable)
if [ "${INSTALL_GO:-0}" = "1" ] && ! command -v go; then
	case "$(uname -m)" in
	x86_64)  GO_ARCH=amd64 ;;
	aarch64) GO_ARCH=arm64 ;;
	*) echo "install-base: unsupported arch: $(uname -m)" >&2; exit 1 ;;
	esac
	GO_VERSION="$(curl -fsSL 'https://go.dev/VERSION?m=text' | head -1)"
	echo "install-base: installing ${GO_VERSION} for linux/${GO_ARCH}"
	curl -fsSL "https://go.dev/dl/${GO_VERSION}.linux-${GO_ARCH}.tar.gz" | tar -xz -C /usr/local
	# expose the toolchain in /usr/local/bin
	ln -sf /usr/local/go/bin/go /usr/local/go/bin/gofmt /usr/local/bin/
fi

# cleanup
rm -rf /var/lib/apt/lists/*

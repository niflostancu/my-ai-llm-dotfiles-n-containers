#!/bin/bash
# Goose harness installer for the shared agent devcontainer feature.
# Sourced by base/devcontainer/feature/install.sh (root, build time).
# Installs the official prebuilt CLI: only glibc/libstdc++ are needed at runtime.
# Keep GOOSE_VERSION in sync with GOOSE_BRANCH in goose/Makefile.

GOOSE_VERSION=${GOOSE_VERSION:-v1.45.0}

install_harness() {
	local arch url tmp
	case "$(uname -m)" in
	x86_64) arch=x86_64 ;;
	aarch64 | arm64) arch=aarch64 ;;
	*)
		echo "[goose harness] unsupported arch: $(uname -m)" >&2
		return 1
		;;
	esac
	url="https://github.com/aaif-goose/goose/releases/download/${GOOSE_VERSION}"
	url="$url/goose-${arch}-unknown-linux-gnu.tar.gz"

	tmp=$(mktemp -d)
	curl -fsSL --retry 3 -o "$tmp/goose.tgz" "$url" || {
		echo "[goose harness] download failed: $url" >&2
		return 1
	}
	tar -xzf "$tmp/goose.tgz" -C "$tmp"
	install -m 0755 "$tmp/goose" /usr/local/bin/goose
	rm -rf "$tmp"
	echo "[goose harness] installed goose ${GOOSE_VERSION}"
}

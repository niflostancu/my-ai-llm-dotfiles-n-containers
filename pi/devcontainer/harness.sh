#!/bin/bash
# Pi harness installer for the shared agent devcontainer feature.
# Sourced by base/devcontainer/feature/install.sh (root, build time).
# VARIANT: pi / little / omp

install_harness() {
	case "${VARIANT:-pi}" in
	pi)
		BUN_INSTALL=/usr/local bun install -g --ignore-scripts \
			@earendil-works/pi-coding-agent pi-acp
		;;
	little)
		BUN_INSTALL=/usr/local bun install -g little-coder
		;;
	omp)
		curl -fsSL https://omp.sh/install |
			PI_INSTALL_DIR=/usr/local/bin sh -s -- --binary
		;;
	*)
		echo "[pi harness] unknown variant: $VARIANT" >&2
		return 1
		;;
	esac
}

#!/bin/bash
# Installs code indexing tools (run as root)
set -eo pipefail

# install Cymbal (latest release binary from GitHub)
case "$(uname -m)" in
  x86_64)  arch=x86_64 ;;
  aarch64) arch=arm64 ;;
  arm64)   arch=arm64 ;;
  *) echo "unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac
os=linux

url="https://api.github.com/repos/1broseidon/cymbal/releases/latest"
version=$(curl -fsSL "$url" | grep -oP '"tag_name":\s*"\K[^"]+')
asset="cymbal_${version}_${os}_${arch}.tar.gz"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl -fsSL -o "$tmp/$asset" "https://github.com/1broseidon/cymbal/releases/download/${version}/${asset}"
tar -xzf "$tmp/$asset" -C "$tmp"

install -m 0755 "$tmp/cymbal" /usr/local/bin/cymbal
echo "installed cymbal ${version} to /usr/local/bin/cymbal"

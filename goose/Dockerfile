# Start from the official Goose Dockerfile:
# https://github.com/aaif-goose/goose/blob/main/documentation/docs/docker/Dockerfile
FROM ghcr.io/aaif-goose/goose:latest

USER root
RUN export DEBIAN_FRONTEND="noninteractive"; \
	apt-get update && apt-get install -y \
		iputils-ping netcat-openbsd neovim \
	&& rm -rf /var/lib/apt/lists/*

# change back to our non-privileged user
USER goose
WORKDIR /workspace


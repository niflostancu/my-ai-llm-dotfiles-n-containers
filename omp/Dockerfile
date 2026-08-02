# Dockerfile for containerized Oh-My-Pi agent

ARG BASE_IMAGE="personal/ai-agent-base"

# runtime stage (using our base image)
FROM ${BASE_IMAGE}

# install extra packages
RUN export DEBIAN_FRONTEND="noninteractive"; \
	apt-get update && apt-get install -y \
		 neovim \
	&& rm -rf /var/lib/apt/lists/*

ENV PI_CODING_AGENT_DIR="${HOME}/.config/pi"

# install omp
RUN curl -fsSL https://omp.sh/install | \
	PI_INSTALL_DIR=/usr/local/bin sh -s -- --binary

# install custom shared tools
RUN --mount=from=mcp-addons,target=/tmp/mcp-addons \
	cd /tmp/mcp-addons/code-index-mcp; ./install.sh

RUN rm -rf /tmp/*

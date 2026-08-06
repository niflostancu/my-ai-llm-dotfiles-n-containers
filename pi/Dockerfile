# Dockerfile for containerized Pi agent (various variants)

ARG BASE_IMAGE="personal/ai-agent-base"

FROM ${BASE_IMAGE} AS pi

# install extra packages?
#RUN export DEBIAN_FRONTEND="noninteractive"; \
# 	apt-get update && apt-get install -y \
# 		 neovim \
# 	&& rm -rf /var/lib/apt/lists/*

ENV PATH="/home/agent/.bun/bin:$PATH" \
	PI_CODING_AGENT_DIR="${HOME}/.config/pi-agent" \
 	PI_CODING_AGENT_SESSION_DIR="${HOME}/.local/share/pi-agent/sessions"

# install pi-coding-agent
RUN gosu agent bun install -g --ignore-scripts @earendil-works/pi-coding-agent && \
	gosu agent bun install -g pi-acp

# install custom shared tools
RUN --mount=from=mcp-addons,target=/tmp/mcp-addons \
	cd /tmp/mcp-addons/code-index-mcp && ./install.sh && \
	cd /tmp/mcp-addons/ketch && ./install.sh

ENV PATH="/home/agent/go/bin:$PATH"

RUN rm -rf /tmp/*

FROM pi AS omp

RUN curl -fsSL https://omp.sh/install | \
	PI_INSTALL_DIR=/usr/local/bin sh -s -- --binary

FROM pi AS little

ENV LITTLE_CODER_MODELS_FILE="$PI_CODING_AGENT_DIR/models.json" \
	LITTLE_CODER_EXTENSIONS_DIR="$PI_CODING_AGENT_DIR/extensions"

RUN gosu agent bun install -g little-coder


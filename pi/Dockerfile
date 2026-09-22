# Dockerfile for containerized Pi agent (various variants)

ARG BASE_IMAGE="personal/ai-agent-base"

FROM ${BASE_IMAGE} AS pi

ARG VARIANT=pi

WORKDIR /tmp

ENV PATH="/home/agent/go/bin:/home/agent/.bun/bin:$PATH" \
	PI_CODING_AGENT_DIR="${HOME}/.config/pi-agent" \
 	PI_CODING_AGENT_SESSION_DIR="${HOME}/.local/share/pi-agent/sessions"

# reuse the devcontainer layer install script
COPY --chmod=755 devcontainer/feature/install.sh /tmp/install-devcontainer.sh
RUN --mount=from=mcp-addons,target=/tmp/mcp-addons \
	VARIANT="${VARIANT}" AGENT_BASE_INSTALLED=1 /tmp/install-devcontainer.sh \
    && rm /tmp/install-devcontainer.sh

WORKDIR /workspace
ENV PATH=":$PATH"

RUN rm -rf /tmp/*

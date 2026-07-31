# Dockerfile for containerized AAIF Goose agent

ARG GOOSE_BRANCH="main"
ARG BASE_IMAGE="personal/ai-agent-base"

# Build stage inspired from the official container:
# https://github.com/aaif-goose/goose/blob/main/documentation/docs/docker/Dockerfile
FROM rust:trixie AS builder
ARG GOOSE_BRANCH

RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && \
	apt-get update && apt-get install -y \
		nodejs libdbus-1-dev ca-certificates curl git protobuf-compiler \
	&& rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src
RUN git clone --depth=1 --branch="${GOOSE_BRANCH}" \
	"https://github.com/aaif-goose/goose.git" goose && \
	cd goose && cargo build --release -p goose-cli --no-default-features \
		--features "rustls-tls code-mode tui"

# runtime stage (using our base image)
FROM ${BASE_IMAGE}

# install extra packages
RUN export DEBIAN_FRONTEND="noninteractive"; \
	apt-get update && apt-get install -y \
		 neovim \
	&& rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/src/goose/target/release/goose /usr/local/bin/


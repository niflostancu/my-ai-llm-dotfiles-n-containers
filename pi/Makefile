# Customized Pi Coding Agent makefile

IMAGE_PREFIX = personal/
docker_pi_args = \
	--build-arg "BASE_IMAGE=$(IMAGE_PREFIX)ai-ag-base" \
	--build-context mcp-addons=../mcp-servers/

docker_pi-image-name = ai-ag-pi
docker_pi-dockerfile = Dockerfile
docker_pi-buildx-args = $(docker_pi_args) --target "pi"

-include ../config.local.mk
include ../base/_docker_lib.mk

.PHONY: all build install
all: build
build: docker_pi_build

$(call add_docker_target,docker_pi)

install:
	rsync -avh "./config-pi/" "$(HOME)/.config/pi-agent/"
	install -m0755 "pi-agent.sh" "$(HOME)/.local/bin"


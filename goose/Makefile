# Customized Goose Agent makefile

IMAGE_PREFIX = personal/
docker_goose-image-name = ai-ag-goose
docker_goose-dockerfile = Dockerfile
docker_goose-buildx-args = \
	--build-arg "BASE_IMAGE=$(IMAGE_PREFIX)ai-ag-base" \
	--build-arg "GOOSE_BRANCH=v1.45.0" \
	--build-context mcp-addons=../mcp-servers/

-include config.local.mk
include ../base/_docker_lib.mk

.PHONY: all install
all: docker_goose_build

$(call add_docker_target,docker_goose)

install:
	rsync -avh "./config/" "$(HOME)/.config/goose/"
	install -m0755 "goose-agent.sh" "$(HOME)/.local/bin"


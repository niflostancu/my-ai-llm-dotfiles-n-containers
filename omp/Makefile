# Customized Goose Agent makefile

IMAGE_PREFIX = personal/
docker_omp-image-name = ai-ag-omp
docker_omp-dockerfile = Dockerfile
docker_omp-buildx-args = \
	--build-arg "BASE_IMAGE=$(IMAGE_PREFIX)ai-ag-base" \
	--build-context mcp-addons=../mcp-servers/

-include config.local.mk
include ../base/_docker_lib.mk

.PHONY: all install
all: docker_omp_build

$(call add_docker_target,docker_omp)

install:
	rsync -avh "./config/" "$(HOME)/.config/omp/"
	install -m0755 "omp-agent.sh" "$(HOME)/.local/bin"


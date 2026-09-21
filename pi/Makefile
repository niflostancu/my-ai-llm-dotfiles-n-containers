# Customized Pi Coding Agent makefile

# set to either pi/little/omp (recommended: inside config.local.mk)
PI_CFG ?= pi

XDG_DATA_HOME ?= $(HOME)/.local/share

IMAGE_PREFIX = personal/
docker_pi_args = \
	--build-arg "BASE_IMAGE=$(IMAGE_PREFIX)ai-ag-base" \
	--build-context mcp-addons=../mcp-servers/

docker_pi-image-name = ai-ag-pi
docker_pi-dockerfile = Dockerfile
docker_pi-buildx-args = $(docker_pi_args) --target "pi"

docker_omp-image-name = ai-ag-pi-omp
docker_omp-dockerfile = Dockerfile
docker_omp-buildx-args = $(docker_pi_args) --target "omp"

docker_little-image-name = ai-ag-pi-little
docker_little-dockerfile = Dockerfile
docker_little-buildx-args = $(docker_pi_args) --target "little"

-include ../config.local.mk
include ../base/_docker_lib.mk

.PHONY: all build install
all: build
build: docker_$(PI_CFG)_build

$(call add_docker_target,docker_pi)
$(call add_docker_target,docker_omp)
$(call add_docker_target,docker_little)

install:
	PI_SUFFIX=""; [ "$(PI_CFG)" = "pi" ] || PI_SUFFIX="-$(PI_CFG)"; \
		rsync -avh --exclude="node_modules/" --exclude="settings.tpl.json" \
			"./config-$(PI_CFG)/" "$(HOME)/.config/pi-agent$$PI_SUFFIX/"; \
	RUNTIME="$(HOME)/.config/pi-agent$$PI_SUFFIX/settings.json"; \
	TEMPLATE="./config-$(PI_CFG)/settings.tpl.json"; \
	if [ -f "$$RUNTIME" ]; then \
		jq -s '.[0] * .[1]' "$$RUNTIME" "$$TEMPLATE" > "$$RUNTIME.tmp" && mv "$$RUNTIME.tmp" "$$RUNTIME"; \
	else \
		jq '.' "$$TEMPLATE" > "$$RUNTIME"; \
	fi; \
	echo "PI_CFG=$(PI_CFG)" > "$(HOME)/.config/pi-agent-default.env"
	ln -sf "$(abspath pi-agent.sh)" "$(HOME)/.local/bin/pi-agent.sh"


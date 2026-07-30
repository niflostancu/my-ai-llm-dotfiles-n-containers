# Build script for base container + scripts

IMAGE_PREFIX = personal/
docker_base-image-name = ai-ag-base
docker_base-dockerfile = Dockerfile.base

-include config.local.mk
include _docker_lib.mk

$(call add_docker_target,docker_base)

run_shell:
	docker run -it $(docker_base_image) bash


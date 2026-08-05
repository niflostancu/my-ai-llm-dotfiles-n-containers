# Llama.cpp makefile

IMAGE_PREFIX = personal/

LLAMACPP_IMAGE = llama.cpp-rocm-gfx1100
LLAMA_GIT_URL = "https://github.com/TheTom/llama-cpp-turboquant.git"
LLAMA_GIT_BRANCH = "feature/turboquant-kv-cache"

docker_llamacpp-image-name = $(LLAMACPP_IMAGE)
docker_llamacpp-dockerfile = Dockerfile
docker_llamacpp-buildx-args = \
	--build-arg "LLAMA_GIT_URL=$(LLAMA_GIT_URL)" \
	--build-arg "LLAMA_GIT_BRANCH=$(LLAMA_GIT_BRANCH)"

-include ../config.local.mk
include ../base/_docker_lib.mk

.PHONY: all install
all: docker_llamacpp_build

$(call add_docker_target,docker_llamacpp)


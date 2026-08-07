# Llama.cpp makefile

IMAGE_PREFIX = personal/

GPU_PLATFORM ?= rocm
GPU_ROCM_GFX ?= gfx1100
GPU_CUDA_VERSION ?= 13.3.1
GPU_CUDA_ARCHITECTURES ?= 120

LLAMACPP_GIT_URL = "https://github.com/TheTom/llama-cpp-turboquant.git"
LLAMACPP_GIT_BRANCH = "feature/turboquant-kv-cache"

LLAMACPP_ROCM_IMAGE = llama.cpp-rocm-$(GPU_ROCM_GFX)
LLAMACPP_CUDA_IMAGE ?= llama.cpp-cuda
CUDA_VERSION ?= 13.3.1

docker_llamacpp_common-flags = \
	--build-arg "LLAMACPP_GIT_URL=$(LLAMACPP_GIT_URL)" \
	--build-arg "LLAMACPP_GIT_BRANCH=$(LLAMACPP_GIT_BRANCH)"

docker_llamacpp_rocm-image-name = $(LLAMACPP_ROCM_IMAGE)
docker_llamacpp_rocm-dockerfile = Dockerfile
docker_llamacpp_rocm-buildx-args = \
	$(docker_llamacpp_common-flags)

docker_llamacpp_cuda-image-name = $(LLAMACPP_CUDA_IMAGE)
docker_llamacpp_cuda-dockerfile = Dockerfile.cuda
docker_llamacpp_cuda-buildx-args = \
	$(docker_llamacpp_common-flags) \
	--build-arg "CUDA_VERSION=$(CUDA_VERSION)" \
	--build-arg "LLAMA_CUDA_ARCHITECTURES=$(GPU_CUDA_ARCHITECTURES)"

-include ../config.local.mk
include ../base/_docker_lib.mk

.PHONY: all install
all: build
build: docker_llamacpp_$(GPU_PLATFORM)_build

$(call add_docker_target,docker_llamacpp_rocm)
$(call add_docker_target,docker_llamacpp_cuda)


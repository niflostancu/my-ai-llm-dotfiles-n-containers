# Docker Image Makefile

VERSION := latest
PUSH?=
ALL?=$(PUSH)
LOAD?=$(if $(ALL),,1)

IMAGE_NAME = ai-goose
IMAGE_TAGS = $(VERSION)
IMAGE_PREFIX = personal/
FULL_IMAGE_NAME=$(IMAGE_PREFIX)$(IMAGE_NAME)

PLATFORMS=linux/amd64,linux/arm64
BUILDX_ARGS?=
BUILDX_ARGS+=$(if $(ALL),--platform $(PLATFORMS))
BUILDX_ARGS += $(if $(V),--progress=plain)

-include local.mk

_full_tag_args = $(foreach tag,latest $(IMAGE_TAGS),-t "$(FULL_IMAGE_NAME):$(tag)")

build:
	docker buildx build $(BUILDX_ARGS) $(_full_tag_args) -f Dockerfile \
		$(if $(PUSH),--push,$(if $(LOAD),--load)) .

build_force: BUILDX_ARGS+= --pull --no-cache
build_force: build

push: PUSH=1
push: build

install:
	rsync -avh "./config/" "$(HOME)/.config/goose/"
	install -m0755 "goose-agent.sh" "$(HOME)/.local/bin"

.PHONY: build build_force push run


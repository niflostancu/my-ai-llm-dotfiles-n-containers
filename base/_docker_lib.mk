# Common Docker building macros

# -- Per-target variables ----------------------------------------------
#   $(T)-image-name   -> image name (e.g. personal/myapp)
#   $(T)-image-tags   -> override tags (default: $(VERSION))
#   $(T)-dockerfile   -> path to Dockerfile (default: Dockerfile)
#   $(T)-buildx-args  -> extra buildx args for this target only

# global vars
IMAGE_PREFIX ?= personal/
VERSION ?= latest
BUILDX_PLATFORMS ?= linux/amd64,linux/arm64

# build control vars
FORCE ?=
PULL ?=
PUSH ?=
ALL ?= $(PUSH)
LOAD ?= $(if $(ALL),,1)
DEBUG ?=

EXTRA_BUILDX_ARGS ?=
EXTRA_BUILDX_ARGS += $(if $(ALL),--platform $(BUILDX_PLATFORMS))
EXTRA_BUILDX_ARGS += $(if $(V),--progress=plain)
EXTRA_BUILDX_ARGS += $(if $(FORCE),--no-cache)
EXTRA_BUILDX_ARGS += $(if $(PULL),--pull)
EXTRA_BUILDX_ARGS += $(if $(DEBUG),--progress=plain)

# macro helpers
_def_value = $(if $($(1)),$($(1)),$(2))
_t_dockerfile = $(call _def_value,$(1)-dockerfile,Dockerfile)
_t_image_name = $(call _def_value,$(1)-image-name,)
_t_build_args = $(call _def_value,$(1)-buildx-args,)
_t_full_name = $(IMAGE_PREFIX)$(_t_image_name)
_t_tag_list = $(call _def_value,$(1)-image-tags,$(VERSION))
_t_full_tag_args = $(foreach tag,$(_t_tag_list),-t "$(_t_full_name):$(tag)")

# disable built-in rules + suffixes
MAKEFLAGS += --no-builtin-rules
.SUFFIXES:

# Macro to build a single image
define docker_build_target
$(1)_image := $(_t_full_name)
.PHONY: $(1)_build
$(1)_build:
	docker buildx build $(_t_build_args) $$(EXTRA_BUILDX_ARGS) \
		-f $(_t_dockerfile) $(_t_full_tag_args) \
		$$(if $$(PUSH),--push,$$(if $$(LOAD),--load)) .
endef

# aggregate rule to build all targets
define docker_build_all
.PHONY: docker_build_all
docker_build_all:
	@for target in $(DOCKER_TARGETS); do \
		$(MAKE) --no-print-directory -f "$(lastword $(MAKEFILE_LIST))" \
			DOCKER_TARGET=$$target $(target)_build; \
	done
endef

# use $(call add_docker_target,my-target-name) to add a single target
define add_docker_target
$(eval $(docker_build_target))
$(eval DOCKER_TARGETS += $(1))
endef

# use $(eval $(docker_build_all)) to inject add global `docker_all` target
DOCKER_TARGETS ?=


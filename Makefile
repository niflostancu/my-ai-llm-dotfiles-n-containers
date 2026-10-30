# Top-level makefile for personal AI/LLM tooling

.PHONY: docker_all docker_base docker_goose docker_pi install_all

docker_all: docker_base docker_goose docker_pi

docker_base:
	$(MAKE) -C base

docker_llamacpp:
	$(MAKE) -C llama.cpp

docker_goose:
	$(MAKE) -C goose

docker_pi:
	$(MAKE) -C pi

install_all:
	$(MAKE) -C goose install

# ---- lint --------------------------------------------------------------
# see scripts/lint.sh (needs shellcheck, jq, python3-yaml)

.PHONY: lint lint-sh lint-config
lint:
	@./scripts/lint.sh
lint-sh:
	@./scripts/lint.sh sh
lint-config:
	@./scripts/lint.sh config

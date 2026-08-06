# Top-level makefile for personal AI/LLM tooling

.PHONY: docker_all docker_base docker_goose docker_pi

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

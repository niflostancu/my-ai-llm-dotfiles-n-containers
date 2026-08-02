# Top-level makefile for personal AI/LLM tooling

.PHONY: docker_all docker_base docker_goose docker_omp

docker_all: docker_base docker_goose docker_omp

docker_base:
	$(MAKE) -C base

docker_llamacpp:
	$(MAKE) -C llama.cpp

docker_goose:
	$(MAKE) -C goose

docker_omp:
	$(MAKE) -C omp

install_all:
	$(MAKE) -C goose install

#!/bin/bash
# Llama.cpp build & install script
set -euo pipefail

LLAMA_GPU_TARGETS=${LLAMA_GPU_TARGETS:-"gfx1100"}

LLAMA_CMAKE_ARGS=(
	-DCMAKE_BUILD_TYPE=Release
    -DCMAKE_INSTALL_PREFIX=/opt/llama.cpp/
	-DBUILD_SHARED_LIBS=ON
	-DLLAMA_BUILD_TESTS=OFF
	-DLLAMA_USE_SYSTEM_GGML=OFF
	-DGGML_ALL_WARNINGS=OFF
	-DGGML_ALL_WARNINGS_3RD_PARTY=OFF
	-DGGML_BUILD_EXAMPLES=OFF
	-DGGML_BUILD_TESTS=OFF
	-DGGML_LTO=ON
	-DGGML_RPC=ON
	# enable OpenBLAS for CPU
	#-DGGML_BLAS=ON
	#-DGGML_BLAS_VENDOR=OpenBLAS
	#-DGGML_ZENDNN=ON
	-DCMAKE_C_FLAGS="-march=native" \
    -DCMAKE_CXX_FLAGS="-march=native" \
    -DGGML_AVX=ON -DGGML_AVX2=ON -DGGML_AVX512=ON -DGGML_AVX512_VNNI=ON \
    -DGGML_AVX512_BF16=ON
	# Vulkan support
	-DGGML_VULKAN=ON
	-DGGML_CPU_ALL_VARIANTS=ON
	-DGGML_BACKEND_DL=ON
	# prevent warnings / fixes 
	-Wno-author
)

cmake -S . -B build -G Ninja "${LLAMA_CMAKE_ARGS[@]}"
cmake --build build -- -j "$(nproc --ignore=2)"

# install to prefix & remove build files
cmake --install build
rm -rf /opt/llama-build


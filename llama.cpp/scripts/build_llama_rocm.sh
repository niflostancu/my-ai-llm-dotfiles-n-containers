#!/bin/bash
# Llama.cpp build & install script
set -euo pipefail

HIP_DEVICE_LIB_PATH=$(find /opt/rocm -type d -name bitcode -print -quit)
export HIP_DEVICE_LIB_PATH

LLAMA_GPU_TARGETS=${LLAMA_GPU_TARGETS:-"gfx1100"}

LLAMA_CMAKE_ARGS=(
	-DCMAKE_BUILD_TYPE=Release
    -DCMAKE_INSTALL_PREFIX=/opt/llama.cpp/
    -DCMAKE_HIP_COMPILER=/opt/rocm/llvm/bin/clang++ \
	-DCMAKE_HIP_FLAGS="-mllvm --amdgpu-unroll-threshold-local=600"
    -DCMAKE_C_COMPILER=/opt/rocm/llvm/bin/clang \
    -DCMAKE_CXX_COMPILER=/opt/rocm/llvm/bin/clang++ \
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
	# ROCm part
	-DGGML_HIP=ON
	-DGGML_HIPBLAS=ON
	-DGGML_HIP_GRAPHS=ON
	# -DGGML_HIP_NO_VMM=ON
	-DGGML_HIP_ROCWMMA_FATTN=ON
	-DHIP_PLATFORM=amd
	-DGPU_TARGETS="$LLAMA_GPU_TARGETS"
	-DGGML_CUDA_FA_ALL_QUANTS=ON
	# Vulkan support
	#-DGGML_VULKAN=ON
	# prevent warnings / fixes 
	-Wno-author
	-DCMAKE_HIP_FLAGS="-Wno-unused-value"
)

cmake -S . -B build -G Ninja "${LLAMA_CMAKE_ARGS[@]}"
cmake --build build -- -j "$(ncpu --ignore=2)"

# install to prefix & remove build files
cmake --install build
rm -rf /opt/llama-build


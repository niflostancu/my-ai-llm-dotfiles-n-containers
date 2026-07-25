# Build custom llama.cpp / forks from source TheRock ROCm for gfx110X (7900XT[X])
FROM ubuntu:26.04

ARG ROCM_VERSION_PREFIX=7
ARG ROCM_GFX=gfx110X

ARG LLAMA_GIT_URL=https://github.com/ggml-org/llama.cpp.git
ARG LLAMA_GIT_BRANCH=15fa3c493

# Install dependencies
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git aria2 tar xz-utils procps \
      build-essential cmake ninja-build npm \
      libatomic1 libnuma-dev libgomp1 libelf1t64 libgoogle-perftools4 \
      libdrm-dev zlib1g-dev libssl-dev libcurl4-openssl-dev \
    && rm -rf /var/cache/apt/archives /var/lib/apt/lists/*

# Download & unpack TheRock ROCm SDK to /opt/rocm (using script)
WORKDIR /tmp
COPY --chmod=755 scripts/install_rocm_sdk.sh /tmp/install_rocm_sdk.sh
RUN ROCM_VERSION_PREFIX=${ROCM_VERSION_PREFIX} ROCM_GFX=${ROCM_GFX} /tmp/install_rocm_sdk.sh

ENV ROCM_PATH=/opt/rocm HIP_PATH=/opt/rocm HIP_PLATFORM=amd \
    PATH=/opt/rocm/bin:/opt/rocm/llvm/bin:$PATH \
    CMAKE_PREFIX_PATH=/opt/rocm \
    HIPCXX=/opt/rocm/llvm/bin/clang++ \
    LD_LIBRARY_PATH=/opt/rocm/lib:/opt/rocm/lib64:/opt/rocm/llvm/lib

# Clone llama.cpp (or custom fork)
RUN git clone -b "${LLAMA_GIT_BRANCH}" "${LLAMA_GIT_URL}" /opt/llama.cpp
WORKDIR /opt/llama.cpp
COPY --chmod=755 scripts/build_llama_cpp.sh /tmp/build_llama_cpp.sh
RUN /tmp/build_llama_cpp.sh

ENV PATH=/usr/local/bin:$PATH \
    LD_LIBRARY_PATH=/usr/local/lib:/opt/rocm/lib:/opt/rocm/llvm/lib

WORKDIR /models
CMD ["/bin/bash"]


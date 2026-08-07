# Build custom llama.cpp / forks from source for TheRock ROCm

ARG UBUNTU_VERSION=26.04
FROM ubuntu:${UBUNTU_VERSION} AS builder

ARG ROCM_VERSION_PREFIX=7
ARG ROCM_GFX=gfx110X

ARG LLAMACPP_GIT_URL=https://github.com/ggml-org/llama.cpp.git
ARG LLAMACPP_GIT_BRANCH=master

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
RUN git clone -b "${LLAMACPP_GIT_BRANCH}" "${LLAMACPP_GIT_URL}" /opt/llama-build
WORKDIR /opt/llama-build
COPY --chmod=755 scripts/build_llama_rocm.sh /tmp/build_llama_rocm.sh
RUN /tmp/build_llama_rocm.sh

FROM ubuntu:${UBUNTU_VERSION}

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl tar xz-utils procps \
      libatomic1 libnuma1 libgomp1 libstdc++6 \
    && rm -rf /var/cache/apt/archives /var/lib/apt/lists/*

COPY --from=builder /opt/llama.cpp/ /opt/llama.cpp/

COPY --from=builder /opt/rocm/lib/libamdhip64.so* \
    /opt/rocm/lib/libhsa-*.so* /opt/rocm/lib/libhipblas*.so* \
    /opt/rocm/lib/libroc*.so* /opt/rocm/lib/libamd_comgr*.so* \
    /opt/rocm/lib/
COPY --from=builder /opt/rocm/llvm/lib/*.so* /opt/rocm/llvm/lib/
COPY --from=builder /opt/rocm/lib/rocm_sysdeps/ /opt/rocm/lib/rocm_sysdeps
COPY --from=builder /opt/rocm/lib/rocblas/library /opt/rocm/lib/rocblas/library

ENV PATH=/opt/llama.cpp/bin:$PATH \
    LD_LIBRARY_PATH=/opt/llama.cpp/lib:/opt/rocm/lib:/opt/rocm/llvm/lib

WORKDIR /models
CMD ["/bin/bash"]


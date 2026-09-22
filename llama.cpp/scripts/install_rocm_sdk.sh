#!/bin/bash
# Install TheRock ROCm SDK for gfx110X via tarball.
# Adapted from https://github.com/hec-ovi/llama-qwen
set -euo pipefail
set -x

ROCM_VERSION_PREFIX=${ROCM_VERSION_PREFIX:-10}
ROCM_VERSION_PATTERN="${ROCM_VERSION_PATTERN:-"all-$ROCM_VERSION_PREFIX\\."}"
ROCM_GFX="${ROCM_GFX:-gfx110X}"

echo "=== Installing TheRock ROCm SDK ($ROCM_GFX, major version $ROCM_VERSION_PATTERN) ==="

cd /var/build-cache/

THEROCK_BASE="https://stable.repo.amd.com/rocm/core/tarball/"
THEROCK_TARBALL_PFX="therock-dist-linux-${ROCM_GFX}-"

# resolve latest tarball key from S3 bucket listing
# Note: this returns XML, uses ugly bash hack to "parse" it
KEY="$(curl -s "${THEROCK_BASE}" \
    | tr '<' '\n' \
    | grep -oP "${THEROCK_TARBALL_PFX}${ROCM_VERSION_PATTERN}.*?\\.tar\\.gz" \
    | sort -V | tail -n1 || true)"

if [ -z "$KEY" ]; then
  echo "ERROR: no tarball matching ${THEROCK_TARBALL_PFX} found at ${THEROCK_BASE}" >&2
  exit 1
fi

ROCM_ARCHIVE=$(basename "$KEY")

if [[ -f "$ROCM_ARCHIVE" ]]; then
    echo "$ROCM_ARCHIVE already found in build cache ;)"
else
    echo "Downloading tarball: ${KEY}"
    aria2c -x 16 -s 16 -j 16 --file-allocation=none "${THEROCK_BASE}${KEY}" -o "$ROCM_ARCHIVE"
fi
mkdir -p /opt/rocm
tar xzf "$ROCM_ARCHIVE" -C /opt/rocm --strip-components=1

echo "Optimizing ROCm package (removing unneeded files)..."
(
    cd /opt/rocm
    # remove test/benchmark applications
    rm -rf ./clients ./tests
    rm -rf ./bin/*-test ./bin/*-bench ./bin/*test* ./bin/*example*
)

# Drop a profile.d fragment so interactive shells in the container pick up
# the ROCm env automatically. The Dockerfile ALSO sets the same variables
# via ENV so non-interactive RUN layers see them during build.
BITCODE_PATH=$(find /opt/rocm -type d -name bitcode -print -quit)
cat > /etc/profile.d/rocm-sdk.sh <<EOF
export ROCM_PATH=/opt/rocm
export HIP_PLATFORM=amd
export HIP_PATH=/opt/rocm
export HIP_CLANG_PATH=/opt/rocm/llvm/bin
export HIP_DEVICE_LIB_PATH=${BITCODE_PATH}
export PATH=/opt/rocm/bin:/opt/rocm/llvm/bin:\$PATH
export LD_LIBRARY_PATH=/opt/rocm/lib:/opt/rocm/lib64:/opt/rocm/llvm/lib:\$LD_LIBRARY_PATH
export ROCBLAS_USE_HIPBLASLT=1
export TORCH_ROCM_AOTRITON_ENABLE_EXPERIMENTAL=1
export VLLM_TARGET_DEVICE=rocm
export HIP_FORCE_DEV_KERNARG=1
export RAY_EXPERIMENTAL_NOSET_ROCR_VISIBLE_DEVICES=1
export LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libtcmalloc_minimal.so.4
EOF
chmod 0644 /etc/profile.d/rocm-sdk.sh

echo "Bitcode path: ${BITCODE_PATH}"
echo "=== ROCm SDK install complete ==="


#!/usr/bin/env bash
set -euo pipefail

SEQUENCER_DIR="/Users/lucas/sequencer"
OUTPUT_DIR="$(cd "$(dirname "$0")" && pwd)/rust"
TARGET="aarch64-apple-ios-sim"
TOOLCHAIN="nightly-2025-07-14"

# iOS Simulator SDK
SDKROOT="$(xcrun --sdk iphonesimulator --show-sdk-path)"
export SDKROOT

# Cross-compilation environment for C dependencies (e.g. ring).
export CC_aarch64_apple_ios_sim="$(xcrun --sdk iphonesimulator --find clang)"
export AR_aarch64_apple_ios_sim="$(xcrun --sdk iphonesimulator --find ar)"
export CFLAGS_aarch64_apple_ios_sim="-isysroot ${SDKROOT}"

# Add cargo/rustup and homebrew to PATH.
eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null)" || true
export PATH="$HOME/.cargo/bin:$HOME/.rustup/bin:${SEQUENCER_DIR}/sequencer_venv/bin:$PATH"

echo "Building tx_prover_ffi for ${TARGET} (release)..."
echo "SDK: ${SDKROOT}"

rustup run "${TOOLCHAIN}" cargo build \
  --manifest-path "${SEQUENCER_DIR}/Cargo.toml" \
  -p tx_prover_ffi \
  --target "${TARGET}" \
  --release

# Copy the static library to the output directory.
LIB_PATH="${SEQUENCER_DIR}/target/${TARGET}/release/libtx_prover_ffi.a"
if [ -f "${LIB_PATH}" ]; then
  cp "${LIB_PATH}" "${OUTPUT_DIR}/libtx_prover_ffi.a"
  echo "Copied to ${OUTPUT_DIR}/libtx_prover_ffi.a"
  file "${OUTPUT_DIR}/libtx_prover_ffi.a"
else
  echo "ERROR: ${LIB_PATH} not found"
  exit 1
fi

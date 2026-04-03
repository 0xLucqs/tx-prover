#!/usr/bin/env bash
set -euo pipefail

SEQUENCER_DIR="/Users/lucas/sequencer"
OUTPUT_DIR="$(cd "$(dirname "$0")" && pwd)/rust"
TOOLCHAIN="nightly-2025-07-14"

# Add cargo/rustup and homebrew to PATH.
eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null)" || true
export PATH="$HOME/.cargo/bin:$HOME/.rustup/bin:${SEQUENCER_DIR}/sequencer_venv/bin:$PATH"

# Build for both targets: real device + simulator.
TARGETS=("aarch64-apple-ios" "aarch64-apple-ios-sim")

for TARGET in "${TARGETS[@]}"; do
  if [[ "$TARGET" == *"-sim" ]]; then
    SDK="iphonesimulator"
    ENV_SUFFIX="aarch64_apple_ios_sim"
  else
    SDK="iphoneos"
    ENV_SUFFIX="aarch64_apple_ios"
  fi

  SDKROOT="$(xcrun --sdk "$SDK" --show-sdk-path)"
  export SDKROOT
  export "CC_${ENV_SUFFIX}=$(xcrun --sdk "$SDK" --find clang)"
  export "AR_${ENV_SUFFIX}=$(xcrun --sdk "$SDK" --find ar)"
  export "CFLAGS_${ENV_SUFFIX}=-isysroot ${SDKROOT}"

  echo "Building tx_prover_ffi for ${TARGET} (release)..."
  echo "SDK: ${SDKROOT}"

  rustup run "${TOOLCHAIN}" cargo build \
    --manifest-path "${SEQUENCER_DIR}/Cargo.toml" \
    -p tx_prover_ffi \
    --target "${TARGET}" \
    --release
done

# Create universal (fat) library combining device + simulator.
DEVICE_LIB="${SEQUENCER_DIR}/target/aarch64-apple-ios/release/libtx_prover_ffi.a"
SIM_LIB="${SEQUENCER_DIR}/target/aarch64-apple-ios-sim/release/libtx_prover_ffi.a"

# Copy device lib (for real iPhone).
cp "${DEVICE_LIB}" "${OUTPUT_DIR}/libtx_prover_ffi-device.a"
# Copy sim lib (for simulator).
cp "${SIM_LIB}" "${OUTPUT_DIR}/libtx_prover_ffi-sim.a"

# Create XCFramework so Xcode picks the right one automatically.
rm -rf "${OUTPUT_DIR}/TxProverFFI.xcframework"
xcodebuild -create-xcframework \
  -library "${OUTPUT_DIR}/libtx_prover_ffi-device.a" \
  -headers "${OUTPUT_DIR}/tx_prover_ffi.h" \
  -library "${OUTPUT_DIR}/libtx_prover_ffi-sim.a" \
  -headers "${OUTPUT_DIR}/tx_prover_ffi.h" \
  -output "${OUTPUT_DIR}/TxProverFFI.xcframework"

echo "Created ${OUTPUT_DIR}/TxProverFFI.xcframework"

# Also keep a plain .a for backwards compat.
cp "${DEVICE_LIB}" "${OUTPUT_DIR}/libtx_prover_ffi.a"
echo "Done."

#!/bin/bash
set -e

echo "Building test-secrets-ark for wasm32-wasip1..."

cargo build --target wasm32-wasip1 --release

echo "Build complete!"
echo "WASM file: target/wasm32-wasip1/release/test-secrets-ark.wasm"
echo ""
echo "File size:"
ls -lh target/wasm32-wasip1/release/test-secrets-ark.wasm

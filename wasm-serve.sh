#!/usr/bin/bash

set -ex

RUSTFLAGS='-C target-feature=+atomics,+bulk-memory,+mutable-globals --cfg=web_sys_unstable_apis' cargo +nightly build --target wasm32-unknown-unknown -Z build-std=std,panic_abort

rm -rf ./dist

mkdir -p ./dist
wasm-bindgen \
  --out-dir ./dist \
  --target no-modules \
  ./target/wasm32-unknown-unknown/debug/turtlico_editor.wasm

cp ./turtlico_editor/index.html ./dist/index.html
cp -r ./turtlico_editor/assets/* ./dist

cd ./dist && python3 ../wasm-server.py

#!/usr/bin/bash
set -e

PROFILE="dev"
SERVE=1
HTTPS=0

for i in "$@"; do
  case $i in
    -p=*|--profile=*)
      PROFILE="${i#*=}"
      shift
      ;;
    -s|--serve)
      SERVE=1
      shift
      ;;
    -s|--https)
      HTTPS=1
      shift
      ;;
    -b|--build-only)
      SERVE=0
      shift
      ;;
    -*|--*)
      echo "Unknown option $i"
      exit 1
      ;;
    *)
      ;;
  esac
done

RUSTFLAGS='-C target-feature=+atomics,+bulk-memory,+mutable-globals --cfg=web_sys_unstable_apis'

RUSTFLAGS=$RUSTFLAGS cargo +nightly build --profile "$PROFILE" --target wasm32-unknown-unknown -Z build-std=std,panic_abort

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
DIST_DIR="./dist"
DEST_DIR="$DIST_DIR/$PROFILE"

rm -rf "$DEST_DIR"

mkdir -p "$DEST_DIR"

echo "Running wasm-bindgen..."
wasm-bindgen \
  --out-dir "$DEST_DIR" \
  --target no-modules \
  "$SCRIPT_DIR/target/wasm32-unknown-unknown/debug/turtlico_editor.wasm"

if [[ $PROFILE -eq "release" ]]; then
  echo "Optimizing WASM..."
  wasm-opt -O3 --fast-math -o "$DEST_DIR/turtlico_editor_bg.wasm" "$DEST_DIR/turtlico_editor_bg.wasm"
fi

echo "Copying assets..."
cp "$SCRIPT_DIR/turtlico_editor/index.html" "$DEST_DIR/index.html"
cp -r "$SCRIPT_DIR/turtlico_editor/assets/"* "$DEST_DIR"

if [[ $SERVE -eq 1 ]]; then
  if [[ $HTTPS -eq 1 ]]; then
    cd "$DIST_DIR" && python3 "$SCRIPT_DIR/wasm-server.py" --https
  else
    cd "$DIST_DIR" && python3 "$SCRIPT_DIR/wasm-server.py"
  fi
fi

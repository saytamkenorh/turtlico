#!/usr/bin/bash
set -e

PROFILE="dev"
SERVE=1
HTTPS=0

for i in "$@"; do
  case $i in
    -p=*|--p=*)
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
DEST_DIRT="$DIST_DIR/$PROFILE"

rm -rf "$DEST_DIRT"

mkdir -p "$DEST_DIRT"
wasm-bindgen \
  --out-dir "$DEST_DIRT" \
  --target no-modules \
  "$SCRIPT_DIR/target/wasm32-unknown-unknown/debug/turtlico_editor.wasm"

cp "$SCRIPT_DIR/turtlico_editor/index.html" "$DEST_DIRT/index.html"
cp -r "$SCRIPT_DIR/turtlico_editor/assets/"* "$DEST_DIRT"

if [[ $SERVE -eq 1 ]]; then
  if [[ $HTTPS -eq 1 ]]; then
    cd "$DIST_DIR" && python3 "$SCRIPT_DIR/wasm-server.py" --https
  else
    cd "$DIST_DIR" && python3 "$SCRIPT_DIR/wasm-server.py"
  fi
fi

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

for file in "$SCRIPT_DIR/icons_raw/"*; do
    if [ -f "$file" ]; then
        filename=$(basename -- "$file")
        src="$file"
        dist="$SCRIPT_DIR/icons/$filename"
        echo "$src -> $dist"
        scour -i "$src" -o "$dist" --enable-viewboxing --enable-id-stripping \
            --enable-comment-stripping --shorten-ids --indent=none
    fi
done

# Favicon
inkscape --export-type=png --export-filename="$SCRIPT_DIR/assets/favicon.png" -w 48 -h 48 "$SCRIPT_DIR/icons_raw/turtlico.svg"
convert "$SCRIPT_DIR/assets/favicon.png" "$SCRIPT_DIR/assets/favicon.ico"
rm "$SCRIPT_DIR/assets/favicon.png"

# PWA icons
inkscape --export-type=png --export-filename="$SCRIPT_DIR/assets/icon-256.png" -w 256 -h 256 "$SCRIPT_DIR/icons_raw/turtlico.svg"
inkscape --export-type=png --export-filename="$SCRIPT_DIR/assets/icon-1024.png" -w 1024 -h 1024 "$SCRIPT_DIR/icons_raw/turtlico.svg"
inkscape --export-type=png --export-filename="$SCRIPT_DIR/assets/icon_ios_touch_192" -w 192 -h 192 "$SCRIPT_DIR/icons_raw/turtlico.svg"

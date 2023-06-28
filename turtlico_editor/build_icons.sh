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

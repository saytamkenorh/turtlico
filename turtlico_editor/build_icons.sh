SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
INKSCAPE="flatpak run org.inkscape.Inkscape"
SCOUR="flatpak run --command=scour org.inkscape.Inkscape"
CONVERT="flatpak run --command=convert org.inkscape.Inkscape"

POSITIONAL_ARGS=()
PWA_ICONS="NO"

while [[ $# -gt 0 ]]; do
  case $1 in
    --pwa-icons)
      PWA_ICONS="YES"
      shift
      ;;
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1")
      shift
      ;;
  esac
done

if [ -f "$(which distrobox-host-exec 2> /dev/null)" ]; then
    HOST_EXEC="distrobox-host-exec"
    INKSCAPE="$HOST_EXEC $INKSCAPE"
    SCOUR="$HOST_EXEC $SCOUR"
    CONVERT="$HOST_EXEC $CONVERT"
fi

for file in "$SCRIPT_DIR/icons_raw/"*; do
    if [ -f "$file" ]; then
        filename=$(basename -- "$file")
        src="$file"
        dest="$SCRIPT_DIR/icons/$filename"
        if [ -f "$dest" ] && [ "$src" -ot "$dest" ]; then
            continue
        fi
        echo "$src -> $dest"
        $SCOUR -i "$src" -o "$dest" --enable-viewboxing --enable-id-stripping \
            --enable-comment-stripping --shorten-ids --indent=none
    fi
done

if [ $PWA_ICONS == "YES" ]; then
    echo "Exporting favicon and PWA icons..."

    # Favicon
    $INKSCAPE --export-type=png --export-filename="$SCRIPT_DIR/assets/favicon.png" -w 48 -h 48 "$SCRIPT_DIR/icons_raw/turtlico.svg"
    $CONVERT "$SCRIPT_DIR/assets/favicon.png" "$SCRIPT_DIR/assets/favicon.ico"
    rm "$SCRIPT_DIR/assets/favicon.png"

    # PWA icons
    $INKSCAPE --export-type=png --export-filename="$SCRIPT_DIR/assets/icon-256.png" -w 256 -h 256 "$SCRIPT_DIR/icons_raw/turtlico.svg"
    $INKSCAPE --export-type=png --export-filename="$SCRIPT_DIR/assets/icon-1024.png" -w 1024 -h 1024 "$SCRIPT_DIR/icons_raw/turtlico.svg"
    $INKSCAPE --export-type=png --export-filename="$SCRIPT_DIR/assets/icon_ios_touch_192" -w 192 -h 192 "$SCRIPT_DIR/icons_raw/turtlico.svg"
fi

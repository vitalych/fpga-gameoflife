#!/bin/sh
set -x

if [ $# -lt 4 ]; then
    echo "Usage: $0 /path/to/utilities com_port_path com_port_speed  image1.jpg..."
    echo "Example: $0 /c/Users/user/Utilities/Release 921600 \\\\.\\com3 image1.jpg image2.png"
    exit 1
fi

BIN_DIR="$1"
shift

for tool in Serial.exe BitmapConverter.exe; do
    if [ ! -f "$BIN_DIR/$tool" ]; then
        echo Could not find "$BIN_DIR/$tool"
        exit
    fi
done

COM_PORT="$1"
shift

COM_SPEED="$1"
shift

for f in $*; do
 $BIN_DIR/BitmapConverter.exe bin "$f" 4 "$f.bin"
 $BIN_DIR/Serial.exe "$COM_SPEED" "$f.bin" "$COM_PORT"
 rm -f "$f.bin"
done

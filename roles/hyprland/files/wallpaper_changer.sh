#!/usr/bin/env bash

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
INTERVAL=900

if ! pgrep -x "awww-daemon" > /dev/null; then
    awww-daemon &
    sleep $INTERVAL
fi

while true; do
    IMG=$(find "$WALLPAPER_DIR" -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.webp" \) | shuf -n 1)

    if [ -n "$IMG" ]; then
        awww img "$IMG" --transition-type fade --transition-duration 4 --transition-fps 60
    fi

    sleep $INTERVAL
done
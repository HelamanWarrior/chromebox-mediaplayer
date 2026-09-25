#!/bin/bash
DEVICE="/dev/sr0"
STATE_FILE="$HOME/.local/state/disc-autoplay.last"
mkdir -p "$(dirname "$STATE_FILE")"

CURRENT_UUID=$(blkid -o value -s UUID "$DEVICE" 2>/dev/null)

if [ "$1" == "--seed" ]; then
    echo "$CURRENT_UUID" > "$STATE_FILE"
    exit 0
fi

LAST_UUID=$(cat "$STATE_FILE" 2>/dev/null)

[ -z "$CURRENT_UUID" ] && exit 0
[ "$CURRENT_UUID" == "$LAST_UUID" ] && exit 0

echo "$CURRENT_UUID" > "$STATE_FILE"
sleep 2

MOUNT_OUTPUT=$(udisksctl mount -b "$DEVICE")
MOUNT_POINT=$(echo "$MOUNT_OUTPUT" | grep -oP "(?<=at ).*")

if [ -d "$MOUNT_POINT/BDMV" ]; then
  udisksctl unmount -b "$DEVICE" >/dev/null 2>&1
  mpv "bluray://" --bluray-device="$DEVICE"
elif [ -d "$MOUNT_POINT/VIDEO_TS" ]; then
  udisksctl unmount -b "$DEVICE" >/dev/null 2>&1
  mpv "dvd://" --dvd-device="$DEVICE"
else
  udisksctl unmount -b "$DEVICE" >/dev/null 2>&1
fi

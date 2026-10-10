#!/bin/bash
DEVICE="/dev/sr0"
STATE_FILE="$HOME/.local/state/disc-autoplay.last"
mkdir -p "$(dirname "$STATE_FILE")"

#CURRENT_UUID=$(blkid -o value -s UUID "$DEVICE" 2>/dev/null)

#if [ "$1" == "--seed" ]; then
#    echo "$CURRENT_UUID" > "$STATE_FILE"
#    exit 0
#fi
#
#LAST_UUID=$(cat "$STATE_FILE" 2>/dev/null)
#
#[ -z "$CURRENT_UUID" ] && exit 0
#[ "$CURRENT_UUID" == "$LAST_UUID" ] && exit 0
#
#echo "$CURRENT_UUID" > "$STATE_FILE"
#sleep 2

PROPS=$(udevadm info --query=property --name="$DEVICE")

if grep -q '^ID_CDROM_MEDIA_BD=1' <<< "$PROPS"; then
  mpv "bluray://" --bluray-device="$DEVICE"
elif grep -q '^ID_CDROM_MEDIA_DVD=1' <<< "$PROPS"; then
  mpv "dvd://" --dvd-device="$DEVICE"
fi

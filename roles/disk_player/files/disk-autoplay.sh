#!/bin/bash
DEVICE="/dev/sr0"

PROPS=$(udevadm info --query=property --name="$DEVICE")

if grep -q '^ID_CDROM_MEDIA_BD=1' <<< "$PROPS"; then
  mpv "bluray://" --bluray-device="$DEVICE"
elif grep -q '^ID_CDROM_MEDIA_DVD=1' <<< "$PROPS"; then
  mpv "dvd://" --dvd-device="$DEVICE"
fi

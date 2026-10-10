#!/usr/bin/env bash
set -euo pipefail

url="https://fvonline-db.bplaced.net/fv_download.php?lang=eng"
dest_dir="$HOME/.config/aacs"

mkdir -p "$dest_dir"
tmp="$(mktemp -d -p "$dest_dir")"
trap 'rm -rf "$tmp"' EXIT

# Retry for a while in case the network isn't up yet at boot
curl -fsSL --retry 10 --retry-delay 5 --retry-all-errors \
  -o "$tmp/keydb.zip" "$url"

unzip -q -o "$tmp/keydb.zip" -d "$tmp/out"

cfg="$(find "$tmp/out" -type f -iname '*.cfg' | head -n1)"
[ -n "$cfg" ] || { echo "No .cfg file found in zip" >&2; exit 1; }

mv "$cfg" "$dest_dir/KEYDB.cfg"
echo "Updated $dest_dir/KEYDB.cfg"

#!/usr/bin/env bash
set -euo pipefail

CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
source "$CFG_DIR/jellyfin-autobitrate.env"          # JF_URL, JF_TOKEN
CONF="$CFG_DIR/jellyfin-mpv-shim/conf.json"

SAFETY=60        # % of measured throughput the stream may use
MIN_KBPS=2000
MAX_KBPS=80000   # ceiling, so fast networks don't go past what you want
SIZE=16000000    # bytes requested per sample
SAMPLES=5
MAX_TIME=6       # seconds per sample

# Skip if something is already using the link; a running stream skews the result
host="${JF_URL#*://}"; host="${host%%[:/]*}"
ip4="$(getent ahostsv4 "$host" | awk 'NR==1{print $1}')"
iface="$(ip -o route get "$ip4" | sed -n 's/.* dev \([^ ]*\).*/\1/p')"
rx() { cat "/sys/class/net/$iface/statistics/rx_bytes"; }
a=$(rx); sleep 2; b=$(rx)
if (( (b - a) / 2 > 250000 )); then echo "Link busy, skipping"; exit 0; fi

samples=()
for _ in $(seq "$SAMPLES"); do
  # On timeout curl exits 28, but speed_download still holds the average so far
  read -r code bps < <(curl -s -o /dev/null --max-time "$MAX_TIME" \
    -H "Authorization: MediaBrowser Token=\"$JF_TOKEN\"" \
    -w '%{http_code} %{speed_download}\n' \
    "$JF_URL/Playback/BitrateTest?Size=$SIZE" || true)
  [[ "${code:-}" == 200 ]] || { echo "BitrateTest failed (HTTP ${code:-none})" >&2; continue; }
  samples+=("${bps%.*}")
done
(( ${#samples[@]} )) || { echo "No valid samples" >&2; exit 1; }

# Use the slowest sample, not the median: stalls come from the dips
floor=$(printf '%s\n' "${samples[@]}" | sort -n | head -n1)
kbps=$(( floor * 8 / 1000 * SAFETY / 100 ))
kbps=$(( kbps / 500 * 500 ))
(( kbps < MIN_KBPS )) && kbps=$MIN_KBPS
(( kbps > MAX_KBPS )) && kbps=$MAX_KBPS

cur=$(jq -r '.remote_kbps' "$CONF")
echo "Slowest sample ~$(( floor * 8 / 1000000 )) Mbps -> target $kbps kbps (current $cur)"

# Don't rewrite the file for small changes
if (( cur > 0 )) && (( kbps * 100 / cur >= 90 && kbps * 100 / cur <= 110 )); then
  echo "Within 10% of current value, leaving it"
  exit 0
fi

tmp="$(mktemp "$CONF.XXXXXX")"
chmod --reference="$CONF" "$tmp"
jq --argjson k "$kbps" '.remote_kbps = $k' "$CONF" > "$tmp"
mv "$tmp" "$CONF"
echo "Set remote_kbps to $kbps"

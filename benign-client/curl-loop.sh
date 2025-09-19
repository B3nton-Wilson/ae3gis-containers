#!/usr/bin/env bash
set -euo pipefail

IFACE="eth0"
PORT=80
MIN=5
MAX=30
CURL_TIMEOUT=10

# get IPv4 of IFACE using ifconfig (as you requested)
IP=$(ifconfig "$IFACE" 2>/dev/null | awk '/inet /{print $2; exit}')

if [ -z "$IP" ]; then
  echo "Could not determine IPv4 for $IFACE" >&2
  exit 1
fi

NET="${IP%.*}.0/24"
echo "Interface $IFACE IP: $IP"
echo "Scanning network: $NET for hosts with port $PORT open..."


# run nmap and extract IPs with port open (greppable output)
mapfile -t HOSTS < <( nmap -Pn -p "$PORT" --open -oG - "$NET" \
  | awk '/Ports:/{ if($0 ~ /\/open\//) print $2 }' )

if [ ${#HOSTS[@]} -eq 0 ]; then
  echo "No hosts with port $PORT open found in $NET"
  exit 0
fi

echo "Found hosts:"
printf '  %s\n' "${HOSTS[@]}"

# trap ctrl-c
trap 'echo; echo "Interrupted — exiting."; exit 0' INT TERM

# helper to pick a random integer in [MIN,MAX]
rand_int() {
  local range=$((MAX - MIN + 1))
  echo $(( MIN + RANDOM % range ))
}

# main loop: pick a random host each iteration, sleep random time, curl it
while true; do
  sleep_for=$(rand_int)
  sleep "$sleep_for"

  # choose a random host from the HOSTS array
  idx=$(( RANDOM % ${#HOSTS[@]} ))
  TARGET=${HOSTS[$idx]}

  # perform curl (discard body), capture exit status
  if curl -sS --max-time "$CURL_TIMEOUT" "http://$TARGET:$PORT/" >/dev/null; then
    status="ok"
  else
    status="fail"
  fi

  printf '%s curl -> %s:%s (%s) slept %ss\n' "$(date --iso-8601=seconds)" "$TARGET" "$PORT" "$status" "$sleep_for"
done


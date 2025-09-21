#!/bin/bash
set -euo pipefail

# --- CONFIG: change these ---
USER="ae3gis"
PASS="ae3gis123"
IFACE="eth0"
PORT=21
MIN=30
MAX=120
REMOTE_CD=""   # e.g. "/home/ftpuser" or leave empty to skip

# get IPv4 of IFACE using ifconfig (as requested)
IP=$(ifconfig "$IFACE" 2>/dev/null | awk '/inet /{print $2; exit}')
if [ -z "${IP:-}" ]; then
  echo "Could not determine IPv4 for $IFACE" >&2
  exit 1
fi

NET="${IP%.*}.0/24"
echo "Interface $IFACE IP: $IP"
echo "Scanning network $NET for hosts with port $PORT open..."

# find hosts with port open
mapfile -t HOSTS < <( nmap -Pn -p "$PORT" --open -oG - "$NET" \
  | awk '/Ports:/{ if($0 ~ /\/open\//) print $2 }' )

if [ ${#HOSTS[@]} -eq 0 ]; then
  echo "No hosts with port $PORT open found in $NET"
  exit 0
fi

echo "Found hosts:"
printf '  %s\n' "${HOSTS[@]}"

trap 'echo; echo "Interrupted — exiting."; exit 0' INT TERM

rand_int() {
  local range=$((MAX - MIN + 1))
  echo $(( MIN + RANDOM % range ))
}

while true; do
  sleep "$(rand_int)"

  TARGET=${HOSTS[$(( RANDOM % ${#HOSTS[@]} ))]}
  echo "Attempting FTP upload to $TARGET ..."

  # unique name each time (UTC timestamp + random)
  TS=$(date -u +%Y%m%dT%H%M%SZ)
  BASENAME="ftp_test_${TS}_${RANDOM}.txt"
  LOCAL_FILE="/tmp/${BASENAME}"
  REMOTE_FILENAME="${BASENAME}"

  # create a small file to upload
  cat > "$LOCAL_FILE" <<EOF
Hello from $(hostname) at $(date --iso-8601=seconds)
This is a harmless test file for FTP upload.
Local path: $LOCAL_FILE
Remote name: $REMOTE_FILENAME
EOF

  # classic ftp client (non-interactive)
  if ftp -pinv "$TARGET" <<EOF
user $USER $PASS
binary
passive
put $LOCAL_FILE $REMOTE_FILENAME
bye
EOF
  then
    echo "Upload to $TARGET succeeded: $REMOTE_FILENAME"
    rm -f -- "$LOCAL_FILE"  # optional: clean up local file
  else
    echo "Upload to $TARGET failed: $REMOTE_FILENAME"
    # keep local file for troubleshooting
  fi
done
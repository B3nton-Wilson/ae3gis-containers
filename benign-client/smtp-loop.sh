#!/usr/bin/env bash
set -euo pipefail

IFACE="eth0"
PORT=25
MIN=5
MAX=30
CURL_TIMEOUT=10   # used as swaks --timeout
TO_ADDR="test@lab.local"

# Arrays to add randomness
SUBJECTS=(
  "Quick status update"
  "Alert: check this"
  "Network notice"
  "FYI: automated ping"
  "Reminder: do not reply"
  "Service check report"
  "Monthly summary"
  "Action required"
  "Heartbeat message"
  "Test message"
)

SENDERS=(
  "monitor@lab.local"
  "alerts@lab.local"
  "no-reply@lab.local"
  "ops@lab.local"
  "noreply@lab.local"
  "scanner@lab.local"
  "reports@lab.local"
  "service@lab.local"
  "daemon@lab.local"
  "automation@lab.local"
)

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

# helper to pick a random index for array length $1
rand_idx() {
  local len=$1
  echo $(( RANDOM % len ))
}

# main loop: pick a random host each iteration, sleep random time, send email
while true; do
  sleep_for=$(rand_int)
  sleep "$sleep_for"

  # choose a random host from the HOSTS array
  idx=$(( RANDOM % ${#HOSTS[@]} ))
  TARGET=${HOSTS[$idx]}

  # pick random subject and sender
  subj_idx=$(rand_idx "${#SUBJECTS[@]}")
  sender_idx=$(rand_idx "${#SENDERS[@]}")
  SUBJECT="${SUBJECTS[$subj_idx]}"
  FROM="${SENDERS[$sender_idx]}"

  # build a simple body that includes some context
  BODY="Automated message sent to ${TARGET}
Subject: ${SUBJECT}
From: ${FROM}
Timestamp: $(date --iso-8601=seconds)
"

  # send email using swaks to the chosen target
  # --server uses the target IP, --to uses TO_ADDR, --from uses chosen FROM
  # --h-Subject sets the header Subject; --data supplies the body
  swaks --server "$TARGET" \
        --to "$TO_ADDR" \
        --from "$FROM" \
        --h-Subject "$SUBJECT" \
        --data "$BODY" \
        --timeout "$CURL_TIMEOUT" || {
    echo "swaks to $TARGET failed (exit $?)" >&2
  }

done
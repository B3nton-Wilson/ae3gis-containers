#!/usr/bin/env bash
set -euo pipefail

# --- CONFIG: change these ---
HOST="192.168.0.2"
USER="ftpuser"
PASS="ftp123"
LOCAL_FILE="/tmp/ftp_test_upload.txt"
REMOTE_FILENAME="ftp_test_upload.txt"  # name to use on remote server

# create a small file to upload
cat > "$LOCAL_FILE" <<EOF
Hello from $(hostname) at $(date --iso-8601=seconds)
This is a harmless test file for FTP upload.
EOF

# do the upload using the classic ftp client (non-interactive)
# -i: turn off interactive prompting (for mput/mget)
# -n: suppress auto-login (we call user)
# -v: verbose (remove if you want quieter)
if ftp -inv "$HOST" <<EOF
user $USER $PASS
binary
passive
cd /home/ftpuser
put $LOCAL_FILE
bye
EOF
then
  echo "Upload succeeded"
else
  echo "Upload failed"
fi

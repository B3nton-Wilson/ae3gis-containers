#!/usr/bin/env bash
set -euo pipefail

# Allow overriding share path with a volume
mkdir -p "${SMB_SHARE_PATH}"
chmod 0775 "${SMB_SHARE_PATH}"

# Create a matching UNIX account (no shell / no home) for Samba auth
if ! id -u "${SMB_USER}" >/dev/null 2>&1; then
  useradd -M -s /usr/sbin/nologin "${SMB_USER}" || true
fi

# Set the UNIX password (not strictly required for Samba, but harmless)
echo "${SMB_USER}:${SMB_PASS}" | chpasswd

# Create Samba user (non-interactive)
(echo "${SMB_PASS}"; echo "${SMB_PASS}") | smbpasswd -s -a "${SMB_USER}"
smbpasswd -e "${SMB_USER}"

# Build the share section dynamically from env
cat >/etc/samba/shares.conf <<EOF
[${SMB_SHARE_NAME}]
   path = ${SMB_SHARE_PATH}
   browseable = ${SMB_BROWSEABLE}
   read only = ${SMB_READ_ONLY}
   guest ok = ${SMB_GUEST_OK}
   valid users = ${SMB_USER}
   force user = ${SMB_USER}
   create mask = 0664
   directory mask = 0775
EOF

# Include our dynamic shares
if ! grep -q "include = /etc/samba/shares.conf" /etc/samba/smb.conf; then
  echo -e "\ninclude = /etc/samba/shares.conf" >> /etc/samba/smb.conf
fi

# Fix perms so user can write
chown -R "${SMB_USER}:${SMB_USER}" "${SMB_SHARE_PATH}"

/usr/sbin/sshd

# Exec smbd in foreground (via CMD)
exec "$@"
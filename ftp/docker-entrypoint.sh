#!/bin/sh
set -e

# start syslog
rsyslogd

# start ssh
/usr/sbin/sshd

# run vsftpd in foreground
exec /usr/sbin/vsftpd -obackground=NO /etc/vsftpd.conf
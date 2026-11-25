#!/usr/bin/env bash
# Run by the entrypoint of the panubo/sshd image in container#sftp, after it
# created the accounts of SSH_USERS, before sshd starts.
#
# Each user is locked (chroot) in /data/<user>, owned by root as sshd wants,
# and writes in /data/<user>/upload, its own, where its sftp session opens.
set -e
for U in ${SSH_USERS//,/ }; do
  IFS=: read -r name uid gid _ <<< "$U"
  mkdir -p "/data/$name/upload"
  chown 0:0 "/data/$name" && chmod 755 "/data/$name"
  chown "$uid:$gid" "/data/$name/upload" && chmod 700 "/data/$name/upload"
  usermod -d /upload "$name"
done
# Fail the start on a sshd_config sshd refuses.
/usr/sbin/sshd -t -f /etc/sftp/sshd_config

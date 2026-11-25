#!/usr/bin/env bash
# Run by the entrypoint of the panubo/sshd image in container#mirror, before
# sshd: adds the mirror account, of uid 0 to read the files of every user. It
# has no password and no shell: mirror_sshd_config lets it in with a key, for
# a read-only sftp session.
set -e
grep -q '^mirror:' /etc/passwd || {
  echo 'mirror:x:0:0:read-only mirror:/:/sbin/nologin' >>/etc/passwd
  echo 'mirror:*:20000:0:99999:7:::' >>/etc/shadow
}
# Fail the start on a sshd_config sshd refuses.
/usr/sbin/sshd -t -f /etc/sftp/sshd_config

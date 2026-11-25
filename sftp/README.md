# sftp server

| Minimum OpenSVC version | Minimum grant to deploy |
| --- | --- |
| v3.0.0-rc71 | admin of the namespace |

A step by step tutorial: you will run an sftp server on your OpenSVC
cluster, where each user has an account of their own, locked in a directory
of their own, and signs in with a ssh key, never a password. Your users can
drop their files there: backups, exports, uploads from partners...

The server moves from node to node with its files, its accounts and its host
keys: when it moves, your users connect again to the same address and see the
same server.

## What you need

* An OpenSVC v3 cluster, v3.0.0-rc71 or later on every node, with docker or
  podman on the nodes.
* The `om` command, on a node of the cluster. The commands of this tutorial
  run as root there (`sudo om ...`), or as the admin of the namespace, with
  `om` or `ox` from your workstation.
* A cluster network your users can reach, to take the address of the server
  from. This tutorial takes `default`, which a cluster always has: its
  addresses are reached from the nodes of the cluster only, right for a test.
  For users out of the cluster, take a network they are routed to.
* A volume pool shared between the nodes, a `drbd` one for example, for the
  files to follow the server from node to node. `sudo om pool ls` lists the
  pools: a shared one has `shared` in its capabilities.
* On the computers of your users: an ssh client, which brings the `sftp` and
  `ssh-keygen` commands (Linux, macOS and Windows 10 or later have one).

## How it works

Two objects, in a namespace of your choice, `demo` in this tutorial:

* `demo/cfg/sftp`, a configmap: what you edit.
  * `users`: the accounts, as `name:uid:gid`, separated by commas;
  * `authorized_keys/<user>`: the ssh public key of each user;
  * `sshd_config`: the configuration of the ssh server;
  * `sftp-layout.sh`: a small script making the directories of the users.

  `sshd_config` and `sftp-layout.sh` are added by the service when it is
  first deployed, from this repository: you only add `users` and the keys.

  The keys of the optional mirror endpoint are there too: `mirror_sshd_config`
  and `mirror.sh`, added by the service, and `mirror_keys/mirror`, which you
  add when you enable it.

* `demo/svc/sftp`, the service, running:
  * a volume keeping the files of the users, the host keys of the server,
    and what the service installs from the cfg;
  * an address taken from the cluster network;
  * the sftp server, a container of the `quay.io/panubo/sshd` image, on port 22.

What a user sees, once signed in:

```
/              <- locked in here, can not go up, owned by root
└── upload/    <- where the session opens, the user writes here
```

On the server, this is `/sftproot/<user>/upload` in the volume: no user can
see the files of another.

## Deploy

### 1. Make a ssh key for each user

Each user makes a key pair, on their own computer, and sends you the public
key, the `.pub` file. The private key never leaves their computer.

```
ssh-keygen -t ed25519 -f ~/.ssh/sftp_alice -C alice@sftp
```

`~/.ssh/sftp_alice.pub` is the public key to send you. For this tutorial,
make two of them, for `alice` and `bob`, on the node where you run `om`:

```
ssh-keygen -t ed25519 -N '' -f ~/sftp_alice -C alice@sftp
ssh-keygen -t ed25519 -N '' -f ~/sftp_bob -C bob@sftp
```

### 2. Declare the users

Create the cfg, then add the accounts and the key of each one:

```
sudo om demo/cfg/sftp create
sudo om demo/cfg/sftp key add --name users --value alice:1001:1001,bob:1002:1002
sudo om demo/cfg/sftp key add --name authorized_keys/alice --from ~/sftp_alice.pub
sudo om demo/cfg/sftp key add --name authorized_keys/bob --from ~/sftp_bob.pub
```

Give each user a uid and a gid of their own, from 1000 up, and never reuse
the ones of a user removed: the files on the volume belong to these numbers.

### 3. Deploy the service

```
sudo om demo/svc/sftp deploy --config https://raw.githubusercontent.com/opensvc/opensvc_templates/main/sftp/sftp.conf \
    --kw ip#1.network=default \
    --kw volume#1.size=10g \
    --wait
```

* `ip#1.network`: the cluster network the address of the server is taken from.
* `volume#1.size`: the room for the files of all the users. The volume is
  taken from a shared pool of the cluster: add `--kw volume#1.pool=<pool>` to
  choose which, when there are several.

Check it is up, and read its address, on the `ip#1` line:

```
sudo om demo/svc/sftp instance status -r
```

```
demo/svc/sftp                       up
└ instances
  ├ node2                           down  idle
  └ node1                           up    idle started
    └ resources
      ├ ip#1              ...../..  up    netns default 10.22.199.9/16 in container#0
      ├ volume#1          ........  up    sftp-data
      ├ container#0       ...../..  up    docker ghcr.io/opensvc/pause
      ├ container#mirror  ..D../.3  n/a   docker quay.io/panubo/sshd:1.10.0
      └ container#sftp    ...../.3  up    docker quay.io/panubo/sshd:1.10.0
```

Here the address is `10.22.199.9`. The server runs on one node, `node1`, the
other node standing by. `container#mirror` is the optional mirror endpoint,
disabled (`D`): see [Option: mirroring](#option-mirroring).

The server needs a few seconds after its start to listen: its logs say
`Server listening on 0.0.0.0 port 22` when it does.

```
sudo om demo/svc/sftp container logs sftp
```

### 4. Connect

As alice, with her private key, to the address of the server:

```
echo hello > hello.txt
sftp -i ~/sftp_alice alice@<the address>
```

The first time, ssh asks you to trust the host key of the server: answer
`yes`. Then, at the `sftp>` prompt:

```
sftp> pwd
Remote working directory: /upload
sftp> put hello.txt
sftp> ls
hello.txt
sftp> bye
```

Bob, connecting with his own key, does not see the file of alice. A password,
a shell (`ssh alice@<the address>`) or a key of another user are refused.

### 5. Move the server to the other node

Move it, as a failure of its node would:

```
sudo om demo/svc/sftp switch --to <the other node> --wait
```

Connect again: the same address, the same host key, ssh asks nothing, and
`hello.txt` is there.

## Day to day

### Add a user

Add the key, append the account to `users`, keeping the others, then restart
the sftp server, which reads `users` as it starts. The users connected are cut
for a few seconds:

```
sudo om demo/cfg/sftp key add --name authorized_keys/carol --from ~/sftp_carol.pub
sudo om demo/cfg/sftp key change --name users --value alice:1001:1001,bob:1002:1002,carol:1003:1003
sudo om demo/svc/sftp restart --rid container#sftp
```

See what `users` holds now:

```
sudo om demo/cfg/sftp key decode --name users
```

### Change the key of a user

The new key is used at the next connection, nothing to restart:

```
sudo om demo/cfg/sftp key change --name authorized_keys/alice --from ~/sftp_alice_new.pub
```

### Remove a user

Remove the key, which shuts the user out at once, then the account:

```
sudo om demo/cfg/sftp key remove --name authorized_keys/bob
sudo om demo/cfg/sftp key change --name users --value alice:1001:1001
sudo om demo/svc/sftp restart --rid container#sftp
```

The files of the user stay in the volume, in `/sftproot/bob`.

### Change the configuration of the ssh server

`sshd_config` is a key of the cfg: edit it, then restart the server. The
server checks the configuration as it starts, and refuses to start on an
error: `instance status -r` shows `container#sftp` down, and its logs say
which line is wrong. Fix it, and restart again.

```
sudo om demo/cfg/sftp key edit --name sshd_config
sudo om demo/svc/sftp restart --rid container#sftp
```

### See what happens

The connections, accepted and refused, are in the logs of the server, on the
node it runs on (`-f` to follow them):

```
sudo om demo/svc/sftp container logs sftp
```

## Option: mirroring

To copy the files of every user to another site, as a backup, a mirroring
system there needs to read them all, and to write none. The service has a
second endpoint for it, disabled in the template:

* on port 2222 of the same address;
* one account, `mirror`, reading the files of every user, under
  `/<user>/upload`;
* read-only twice: the sftp session (`internal-sftp -R`), and the files,
  which this endpoint mounts read-only.

On the mirroring system, make its key, and send the public one to the
cluster:

```
ssh-keygen -t ed25519 -N '' -f ~/sftp_mirror -C mirror@sftp
```

On the cluster, add the key as `mirror_keys/mirror`, then enable the endpoint
and start it:

```
sudo om demo/cfg/sftp key add --name mirror_keys/mirror --from ~/sftp_mirror.pub
sudo om demo/svc/sftp config update --set container#mirror.disable=false
sudo om demo/svc/sftp start --rid container#mirror
```

The mirroring system reads, and copies, with any sftp client, for example:

```
sftp -P 2222 -i ~/sftp_mirror mirror@<the address>
sftp> ls /
alice  bob
sftp> get -r /alice/upload alice
```

or with `rsync`-like tools speaking sftp, such as `rclone`. A write, a
delete, a rename are refused, and so are the users on port 2222, and mirror
on port 22. Its logs:

```
sudo om demo/svc/sftp container logs mirror
```

Its configuration is the `mirror_sshd_config` key of the cfg, changed as the
one of the sftp server, restarting `container#mirror`. It accepts more
connections at once than the sftp server, as mirroring tools open many: see
`MaxStartups` there.

Add the mirror after the first start of the service: it reads the host keys
the sftp server made then, the same, so the mirroring system trusts one host
key on both ports.

## Remove the service

```
sudo om demo/svc/sftp purge --wait
```

`purge` removes the service, and leaves its volume, `demo/vol/sftp-data`, with
the files of the users, and the cfg, with the accounts and their keys: deploy
again, and the server is back as it was, its address and host key included.
Only the mirror endpoint is disabled again, as in the template: enable it
again if you use it. When you need the files and the accounts no more, remove
them too:

```
sudo om demo/vol/sftp-data purge --wait
sudo om demo/cfg/sftp delete
```

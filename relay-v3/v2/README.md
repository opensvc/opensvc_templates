# Heartbeat relay

> **Requires OpenSVC agent v3.0.0-rc49 or later** on every node: the relay
> takes its address from a cluster network, a lan network for an address
> other clusters reach, joined as the network says, which earlier agents do
> not have.

A failover service running an OpenSVC agent configured as a heartbeat relay,
in a container: the nodes of the clusters using it post their heartbeats to
it, and read the ones of their peers, so a cluster whose sites lose sight of
each other still tells a dead node from a broken link. A relay is usually
deployed on a third site, and can serve several clusters.

One configuration deploys it on any cluster network: the network decides who
reaches it. Deployed in a namespace of your own, it needs no root grant.

## How it works

* `<ns>/sec/relay-v3` holds the users allowed to send their heartbeats to the
  relay, a key `users/<name>` holding the password of each.
* `<ns>/svc/relay-v3` installs them in a memory volume, takes an address from
  the cluster network `env.network` names, and runs the relay in a container,
  which configures itself from them at each start.

## Deploy

Create the sec, with a user whose password is a random value:

```
$ om ns1/sec/relay-v3 create
$ om ns1/sec/relay-v3 key add --name users/relay --from /dev/urandom
```

Read the password, which the clusters using the relay need:

```
$ om ns1/sec/relay-v3 key decode --name users/relay
```

Create the service, on the cluster network the relay is reached through:

```
$ om ns1/svc/relay-v3 create --config https://raw.githubusercontent.com/opensvc/opensvc_templates/main/relay-v3/v2/relay-v3.conf \
    --kw env.network=backend \
    --provision --wait
```

* A backend network, as a routed_bridge one, gives the relay an address the
  nodes of this cluster reach, and the other clusters routed to it.
* A lan network gives it an address of the segment the network names, as a
  public one other clusters reach. The network says how the segment is
  joined: on nodes whose interface on the segment is not a bridge, root sets
  `network#<name>.modes = macvlan` in the cluster configuration.

The address taken is the one of `ip#1`:

```
$ om ns1/svc/relay-v3 instance status -r
```

The `om` commands above can be `ox` ones, from a workstation.

## Use the relay

On each cluster using the relay, keep the password in a sec, and add a relay
heartbeat:

```
$ om system/sec/relay create
$ om system/sec/relay key add --name password --value '<the password read above>'
$ om cluster config update \
    --set hb#2.type=relay \
    --set hb#2.relay=https://<the relay address>:1215 \
    --set hb#2.username=relay \
    --set "hb#2.password=from system/sec/relay key password"
```

## Options

### More users

Add a key per user, and restart the relay, which reads them at its start:

```
$ om ns1/sec/relay-v3 key add --name users/cluster2 --from /dev/urandom
$ om ns1/svc/relay-v3 restart
```

### Your own certificate

Add the keys of the certificate to the sec, have the volume install them, and
restart the relay:

```
$ om ns1/sec/relay-v3 key add --name ssl/private_key --from /path/to/private_key
$ om ns1/sec/relay-v3 key add --name ssl/certificate_chain --from /path/to/certificate_chain
$ om ns1/svc/relay-v3 config update --set 'volume#1.install+=/config/ssl/ from ./sec/{name} key ssl/*'
$ om ns1/svc/relay-v3 restart
```

### Cluster keywords of the relay

A key `cluster/<keyword>` sets a cluster keyword of the relay agent, as its
listener port:

```
$ om ns1/sec/relay-v3 key add --name cluster/listener.port --value 1216
$ om ns1/svc/relay-v3 config update --set 'volume#1.install+=/config/cluster/ from ./sec/{name} key cluster/*'
$ om ns1/svc/relay-v3 restart
```

# Cluster nameservers

> **Requires OpenSVC agent v3.0.0-rc49 or later** on every node: the
> recursor forwards the reverse zones of the cluster networks, which the
> agent serves and gives the install templates, and which earlier agents do
> not have.

A flex service running, on each node of `cluster.dns`, the authoritative
nameserver of the cluster zone, fed by the agent, and a recursor answering the
clients of the cluster networks.

* The cluster zone, `<clustername>`, holds the names of the objects, as
  `<name>.<namespace>.svc.<clustername>`.
* The reverse zones of the addresses the cluster networks hand out answer
  `dig -x <address>` with the name of the object holding the address. The
  recursor forwards them to the authoritative nameserver, and resolves the
  other names.

The recursor answers the clients of the cluster networks: the volume renders
the `networks` file from the networks of the cluster at each start, each with
its reverse zones, and `configure` makes the recursor configuration of it.

## Requirements

* `cluster.dns = <ip1> [<ip2> ...]` in the cluster configuration, addresses
  of the nodes running the nameservers.
* docker or podman.

## Deploy

```
$ om system/cfg/dns create
$ om system/cfg/dns key add --name server --from https://raw.githubusercontent.com/opensvc/opensvc_templates/main/dns/v2/pdns.conf.template
$ om system/cfg/dns key add --name recursor --from https://raw.githubusercontent.com/opensvc/opensvc_templates/main/dns/v2/recursor.conf.template
$ om system/cfg/dns key add --name networks --from https://raw.githubusercontent.com/opensvc/opensvc_templates/main/dns/v2/networks
$ om system/cfg/dns key add --name configure --from https://raw.githubusercontent.com/opensvc/opensvc_templates/main/dns/v2/configure
$ om system/svc/dns create --config https://raw.githubusercontent.com/opensvc/opensvc_templates/main/dns/v2/dns.conf --provision --wait
```

Check a name and an address of an object:

```
$ dig @<ip1> <name>.<namespace>.svc.<clustername> +short
$ dig @<ip1> -x <its address> +short
```

## Networks

A network added or changed reaches the recursor at its next start:

```
$ om system/svc/dns restart
```

The authoritative nameserver answers the reverse zones of the new network at
once.

## Reverse lookups

A client of the recursor, as a container of any namespace, can list the names
of the objects holding the addresses of a range by looking each address up.
On a cluster where these names are not to be listed, set
`cluster.dns_reverse = false` and restart the service: the agent serves no
reverse zone, and the recursor forwards none.

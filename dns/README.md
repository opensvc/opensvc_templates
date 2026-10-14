# Cluster nameservers

## Template generations

| Generation | Minimum OpenSVC version | Minimum grant to deploy | Reverse lookups |
| --- | --- | --- | --- |
| [v2](v2/README.md) | v3.0.0-rc49 | root: the nameservers run in the host network namespace | answered for the addresses of the cluster networks |
| v1, this page | v2.1-1651 | root: the nameservers run in the host network namespace | not answered |

The files of a generation stay at their url, working with the agents it
requires: a change needing a newer agent comes as a new generation, in a
directory of its own. Use the newest generation your agents support.

The rest of this page is the v1 howto.

# Requirements

* CNI installed
* docker or podman installed
* cluster.dns=ip1 [ip2 ...] configured in cluster.conf

# Deploy the dns service.

```
om system/cfg/dns create
om system/cfg/dns add --key server --from https://raw.githubusercontent.com/opensvc/opensvc_templates/main/dns/pdns.conf.template
om system/cfg/dns add --key recursor --from https://raw.githubusercontent.com/opensvc/opensvc_templates/main/dns/recursor.conf.template
om system/cfg/dns add --key configure --from https://raw.githubusercontent.com/opensvc/opensvc_templates/main/dns/configure
om system/svc/dns deploy --config https://raw.githubusercontent.com/opensvc/opensvc_templates/main/dns/dns.conf
```

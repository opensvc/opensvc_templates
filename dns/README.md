Requirements
* CNI installed
* docker or podman installed
* OpenSVC agent 2.1-448+ installed
* cluster.dns=ip1 [ip2 ...] configured in cluster.conf

Deploy the dns service.
```
om system/cfg/dns create
om system/cfg/dns add --key server --from https://raw.githubusercontent.com/opensvc/opensvc_templates/main/dns/pdns.conf.template
om system/cfg/dns add --key recursor --from https://raw.githubusercontent.com/opensvc/opensvc_templates/main/dns/recursor.conf.template
om system/cfg/dns add --key configure --from https://raw.githubusercontent.com/opensvc/opensvc_templates/main/dns/configure
om system/svc/dns deploy --config https://raw.githubusercontent.com/opensvc/opensvc_templates/main/dns/dns.conf
```

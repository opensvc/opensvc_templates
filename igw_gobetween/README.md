# Requirements

* CNI installed
* docker or podman installed
* OpenSVC agent 2.1+ installed
* Cluster DNS service installed

Create a configmap to host the gobetween configuration.

```
om system/cfg/gobetween create
curl -o- -s https://raw.githubusercontent.com/opensvc/opensvc_templates/main/igw_gobetween/config.json | om system/cfg/gobetween add --key config.json --from -
```

# Failover service publishing on a host ip address

```
om system/svc/gobetween deploy \
  --config https://raw.githubusercontent.com/opensvc/opensvc_templates/main/igw_gobetween/hostns.conf \
  --env public_interface=eth0 \
  --env public_ipaddr=10.0.3.10 \
  --env public_netmask=24 \
```

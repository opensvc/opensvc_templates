# Requirements

* CNI installed
* docker or podman installed
* OpenSVC agent 2.1+ installed

Create a configmap to host the envoy configuration.

```
om system/cfg/envoy create
curl -o- -s https://raw.githubusercontent.com/opensvc/opensvc_templates/main/igw_envoy/xds.yml | om system/cfg/envoy add --key xds.yml --from -
```

# Failover service publishing on a host bridge ip address

```
om system/svc/envoy deploy \
  --config https://raw.githubusercontent.com/opensvc/opensvc_templates/main/igw_envoy/bridge-hostns.conf \
  --env public_interface=br0 \
  --env public_ipaddr=10.0.3.10 \
  --env public_netmask=24 \
```

# Failover service publishing on a host interface ipvlan ip address

```
om system/svc/envoy deploy \
  --config https://raw.githubusercontent.com/opensvc/opensvc_templates/main/igw_envoy/ipvlan.conf
  --env public_interface=eth0 \
  --env public_ipaddr=10.0.3.10 \
  --env public_netmask=24 \
  --env backend_network_name=default
  ```


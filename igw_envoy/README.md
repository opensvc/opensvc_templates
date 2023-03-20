# Requirements

* CNI installed
* docker or podman installed
* OpenSVC agent 2.1+ installed
* Cluster DNS service installed

Create a configmap to host the envoy configuration.

```
om system/cfg/envoy create
curl -o- -s https://raw.githubusercontent.com/opensvc/opensvc_templates/main/igw_envoy/xds.yaml | om system/cfg/envoy add --key xds.yaml --from -
```

# Failover service publishing on a host bridge ip address

```
om system/svc/envoy deploy \
  --config https://raw.githubusercontent.com/opensvc/opensvc_templates/main/igw_envoy/bridge-hostns.conf \
  --env public_interface=br0 \
  --env public_ipaddr=10.0.3.10 \
  --env public_netmask=24
```

# Failover service publishing on a host interface ipvlan ip address

```
om system/svc/envoy deploy \
  --config https://raw.githubusercontent.com/opensvc/opensvc_templates/main/igw_envoy/ipvlan.conf
  --env public_interface=eth0 \
  --env public_ipaddr=10.0.3.10 \
  --env public_gateway=10.0.3.1 \
  --env public_netmask=24 \
  --env backend_network_name=default
  ```

## IPV6 usage

If you plan to use a public ipv6 address, you may need to adjust container configuration to allow ipv6 in container network namespace.

When error message `RTNETLINK answers: Permission denied` is met during service startup, then the following parameter should be applied.

### check for parameter definition in "env" section

```
# om system/svc/envoy get --kw  env.run_args_ipv6
--sysctl net.ipv6.conf.all.disable_ipv6=0
```

### set parameter for docker container holding the network stack

```
# om system/svc/envoy set --kw container#0.run_args={env.run_args_ipv6}
```

### check for correct settings

```
# om system/svc/envoy get --kw container#0.run_args
{env.run_args_ipv6}
# om system/svc/envoy get --kw container#0.run_args --eval
['--sysctl', 'net.ipv6.conf.all.disable_ipv6=0']
```

### restart service

```
# om system/svc/envoy restart
```

### check status

```
# om system/svc/envoy print status -r
system/svc/envoy                   up                                                                      
`- instances              
   `- cl1n1                        up         idle, started            
      |- ip#0             ........ up         netns ipvlan-l2 2001:44a:1234:c1:a65d::2/80 ens4@container#0
      |- ip#1             ........ up         cni backend 10.99.0.11/22 eth12                              
      |- volume#0         ........ up         envoy-data                                                   
      |- container#0      ...../.. up         docker google/pause                                          
      |- container#envoy  ...../.. up         docker envoyproxy/envoy-alpine:v1.12.0                       
      `- container#xds    ...../.. up         docker ghcr.io/opensvc/igw_envoy:1.28                                
```

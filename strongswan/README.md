# StrongSwan IPsec Mesh

## Rationale

When cluster nodes communicate over potentially insecure network links, data encryption is essential for security and compliance.

While key components of the OpenSVC platform are already secured:

* The OpenSVC daemon API is served over HTTPS.
* Data exchanged via heartbeats is encrypted.
* Ingress gateway-to-client traffic is easily encrypted using ACME certificates.

This leaves the service-to-service communications (inter-service traffic) within the cluster's backend networks as the primary vulnerability point.

A solution: StrongSwan IPsec VPN Mesh

Since clusters can host numerous services and backend networks, deploying a VPN mesh offers an elegant, scalable, and non-intrusive solution.

* Encryption Scope: All traffic traversing the OpenSVC backend networks is routed through the mesh endpoints and is encrypted via IPsec.
* Scalability: The VPN solution avoids added complexity with every new service or backend network, making it a foundational layer.

This document details the procedure for deploying a StrongSwan IPsec mesh to achieve these objectives.

## Technical Requirements

To deploy and test the VPN mesh solution, the following components must be available and installed on all participating cluster nodes:

### Deployment

* OpenSVC Agent: Must be installed and operational on all nodes.
* Container Runtime: Docker or Podman must be installed to run test applications that utilize the encrypted backend network.
* StrongSwan/IPsec: The mberner/strongswan container image must be accessible.

### Testing

* Container Network Interface (CNI): An active CNI is required to properly route and test service-to-service traffic using containerized applications.


## Example

```
+------------------------------------------------------------------------+
|                 backendnet (Network CIDR: 10.101.0.0/16)               |
+------------------------------------------------------------------------+
          |                           |                          |
          |                           |                          |
+-----------------+         +-----------------+        +-----------------+
| Internal IP:    |         | Internal IP:    |        | Internal IP:    |
|   10.101.0.1    |         |   10.101.1.1    |        |   10.101.2.1    |
| Subnet:         |         | Subnet:         |        | Subnet:         |
|   10.101.0.0/24 |         |   10.101.1.0/24 |        |   10.101.2.0/24 |
|                 |         |                 |        |                 |
|      node1      |         |      node2      |        |      node3      |
|                 |         |                 |        |                 |
| Public IP:      |         | Public IP:      |        | Public IP:      |
|   10.45.0.11    |         |   10.45.0.12    |        |   10.45.0.13    |
+-----------------+         +-----------------+        +-----------------+
          |                          |                          |
          |                          |                          |
+------------------------------------------------------------------------+
|                        VPN MESH OVERLAY NETWORK                        |
|  (tunnels connect 10.45.0.x peers to allow 10.101.x.x svc to talk)     |
+------------------------------------------------------------------------+
```

## Deploy

### Add the backend network

Execute on a single node (adapt values to your case):

```
$ sudo om cluster config update \
   --set network#backendnet.type=routed_bridge \
   --set network#backendnet.tunnel=never \
   --set network#backendnet.network=10.101.0.0/16 \
   --set network#backendnet.ips_per_node=256 \
   --set network#backendnet.dev=br-prd  # if you want another device instead of the default one
```

Resulting section in the cluster configuration:

```
[network#backendnet]
type = routed_bridge
tunnel = never
network = 10.101.0.0/16
ips_per_node = 256 
dev = br-prd
```
### Deploy the StrongSwan service

Create a new secret data store:
```
$ sudo om system/sec/strongswan create
```

Store the common strongswan config:
```
$ sudo om system/sec/strongswan add --key strongswan --from https://raw.githubusercontent.com/opensvc/opensvc_templates/main/strongswan/strongswan.conf
```

Store the node-specific swanctl configs:
```
$ sudo om system/sec/strongswan add --key swanctl.node1 --from https://raw.githubusercontent.com/opensvc/opensvc_templates/main/strongswan/swanctl.conf
$ sudo om system/sec/strongswan add --key swanctl.node2 --from https://raw.githubusercontent.com/opensvc/opensvc_templates/main/strongswan/swanctl.conf
$ sudo om system/sec/strongswan add --key swanctl.node3 --from https://raw.githubusercontent.com/opensvc/opensvc_templates/main/strongswan/swanctl.conf
```

Adapt the swanctl configs to your IPs, CIDRs and secrets:
```
$ sudo om system/sec/strongswan key edit --name swanctl.node1
$ sudo om system/sec/strongswan key edit --name swanctl.node2
$ sudo om system/sec/strongswan key edit --name swanctl.node3
```

Deploy the strongswan service with the right config :
```
$ sudo om system/svc/strongswan deploy --config https://raw.githubusercontent.com/opensvc/opensvc_templates/main/strongswan/osvc.strongswan.conf
```

## Test

### Deploy a test service on each nodes

```
$ sudo om pod1 deploy \
  --kw nodes=node1 \
  --kw container#1.image=ghcr.io/opensvc/pause \
  --kw container#1.rm=true \
  --kw ip#1.type=cni \
  --kw ip#1.network=backendnet \
  --kw ip#1.netns=container#1
  
$ sudo om pod2 deploy \
  --kw nodes=node2 \
  --kw container#1.image=ghcr.io/opensvc/pause \
  --kw container#1.rm=true \
  --kw ip#1.type=cni \
  --kw ip#1.network=backendnet \
  --kw ip#1.netns=container#1
  
$ sudo om pod3 deploy \
  --kw nodes=node3 \
  --kw container#1.image=ghcr.io/opensvc/pause \
  --kw container#1.rm=true \
  --kw ip#1.type=cni \
  --kw ip#1.network=backendnet \
  --kw ip#1.netns=container#1
```

### Test inter-service communications

Get the IP from the services you created with:
```
$ sudo om net ip list
OBJECT    NODE    RID   IP                           NET_NAME     NET_TYPE       
pod1      node1   ip#1  10.101.0.14                  backendnet   routed_bridge  
pod2      node3   ip#1  10.101.1.79                  backendnet   routed_bridge  
pod3      node3   ip#1  10.101.2.142                 backendnet   routed_bridge  

```

**For each pair of nodes :**

On the receiver node (node2), use tcpdump to see the ESP network traffic:
```
# ipv4
$ sudo tcpdump -i br-prd esp

# ipv6
$ sudo tcpdump -i br-prd ip6 and esp
```

On the other node:

```
# ipv4
nsenter --net=`docker inspect pod1.container.1 | jq -r .[0].NetworkSettings.SandboxKey` ping 10.101.1.1

# ipv6
nsenter `...` ping6 ...
```

### Common issues

#### Packets are transmitted and received (0% packet loss)

Check if the packets are transmitted using ICMP instead of ESP using :
```
# ipv4
$ sudo tcpdump -i br-prd icmp

# ipv6
$ sudo tcpdump -i br-prd ip6 and icmp
```

If the packets are received in ICMP it means that the packets aren't encrypted. Check all the configurations of nodes, services and swanctl to see if all are corrects.

#### All packets are lost (100% packet loss)

- Make sure your nodes can communicate without any VPN tunnel and service and if they can recheck your nodes configuration and services configuration and make sure all the IPs and CIDRs are correct. It can also be due to firewall, ip rules...
- With IPv6, check ip6 firewall tables.

The DROP forward policy is a very common blocker.
```
$ sudo ip6tables -L
...
Chain FORWARD (policy DROP)
...
```
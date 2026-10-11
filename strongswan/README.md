# StrongSwan IPsec Mesh

> **Requires OpenSVC agent v3.0.0-rc47 or later** on every node: the
> configuration is rendered by the agent from the tunnels of each node, with
> install templates, and kept up to date by event-triggered tasks, which earlier
> agents do not have.

## Rationale

When cluster nodes communicate over potentially insecure network links, data encryption is essential for security and compliance.

While key components of the OpenSVC platform are already secured:

* The OpenSVC daemon API is served over HTTPS.
* Data exchanged via heartbeats is encrypted.
* Ingress gateway-to-client traffic is easily encrypted using ACME certificates.

This leaves the service-to-service communications (inter-service traffic) within the cluster's backend networks as the primary vulnerability point.

A solution: StrongSwan IPsec VPN Mesh

Since clusters can host numerous services and backend networks, deploying a VPN mesh offers an elegant, scalable, and non-intrusive solution.

* Encryption Scope: All traffic traversing the OpenSVC backend networks between nodes is carried by tunnels, and the tunnel traffic is encrypted via IPsec.
* Scalability: The VPN solution avoids added complexity with every new service or backend network, making it a foundational layer.
* No per-node configuration: one configuration template serves every node, and follows the nodes joining or leaving the cluster and the key rotations on its own.

This document details the procedure for deploying a StrongSwan IPsec mesh to achieve these objectives.

## Technical Requirements

To deploy and test the VPN mesh solution, the following components must be available and installed on all participating cluster nodes:

### Deployment

* OpenSVC Agent: v3.0.0-rc47 or later, installed and operational on all nodes.
* Container Runtime: Docker or Podman, to run strongSwan and the test applications.
* StrongSwan/IPsec: The mberner/strongswan container image must be accessible. Any image with strongSwan's `charon` and `swanctl` does.
* Backend Network: a `routed_bridge` network carrying the traffic between the nodes in tunnels, `ipip` for an ipv4 network or `ip6ip6` for an ipv6 one, the default tunnel modes.

## How it works

Three objects of the `system` namespace:

* `system/sec/strongswan`: the pre-shared key of the mesh.
* `system/cfg/strongswan`: the strongSwan configuration. Its `swanctl.conf` key is a template the agent renders on each node, into one IPsec transport mode connection per tunnel of the node, encrypting what the tunnel carries.
* `system/svc/strongswan`: a service running on every node, which installs the configuration in a tmpfs, runs strongSwan in a container, and keeps them up to date with two tasks:
  * `task#refresh` installs the configuration again when the peers of a network change: a node joining or leaving, a node address or a tunnel changing.
  * `task#load_all` has strongSwan load the configuration again whenever an install wrote it: the refresh, a start, or a change of the pre-shared key.

## Example

```
+---------------------------------------------------------------------------+
|                   backendnet (Network CIDR: 10.101.0.0/16)                |
+---------------------------------------------------------------------------+
          |                            |                           |
          |                            |                           |
+------------------+         +------------------+        +------------------+
| Private Bridge:  |         | Private Bridge:  |        | Private Bridge:  |
|   obr_backendnet |         |   obr_backendnet |        |   obr_backendnet |
| Internal IP:     |         | Internal IP:     |        | Internal IP:     |
|   10.101.0.1     |         |   10.101.1.1     |        |   10.101.2.1     |
| Subnet:          |         | Subnet:          |        | Subnet:          |
|   10.101.0.0/24  |         |   10.101.1.0/24  |        |   10.101.2.0/24  |
|                  |         |                  |        |                  |
|      node1       |         |      node2       |        |      node3       |
|                  |         |                  |        |                  |
| Bridge:          |         | Bridge:          |        | Bridge:          |
|   br-prd         |         |   br-prd         |        |   br-prd         |
| Public IP:       |         | Public IP:       |        | Public IP:       |
|   10.45.0.11     |         |   10.45.0.12     |        |   10.45.0.13     |
+------------------+         +------------------+        +------------------+
          |                           |                            |
          |                           |                            |
+---------------------------------------------------------------------------+
|                          VPN MESH OVERLAY NETWORK                         |
|   (ipip tunnels between the 10.45.0.x peers carry the 10.101.x.x traffic, |
|    and IPsec encrypts the tunnels)                                        |
+---------------------------------------------------------------------------+
```

## Deploy

### Add the backend network

Execute on a single node (adapt values to your case):

```
$ sudo om cluster config update \
   --set network#backendnet.type=routed_bridge \
   --set network#backendnet.tunnel=always \
   --set network#backendnet.network=10.101.0.0/16 \
   --set network#backendnet.mask_per_node=24
```

`tunnel=always` carries the traffic between the nodes in tunnels even when the
nodes share a subnet, so all of it is encrypted. The tunnel endpoints are the
addresses the node names resolve to: set `network#backendnet.addr@<node>` to
use other addresses.

> [NOTE]
> By default, the backend bridge name is generated automatically `obr_[networkname]`
> With the previous example command, the backend bridge will be created with link name `obr_backendnet`
> If you prefer a custom bridge name, you can add the option below to the previous command
> `--set network#backendnet.dev=br-custom`

Resulting section in the cluster configuration, check with command `$ sudo om cluster config show`:

```
[network#backendnet]
type = routed_bridge
tunnel = always
network = 10.101.0.0/16
mask_per_node = 24
subnet@node1 = 10.101.0.0/24
subnet@node2 = 10.101.1.0/24
subnet@node3 = 10.101.2.0/24
```

The subnets of the other nodes are routed through `otun*` tunnel devices:

```
user@node1:~$ ip route show | grep ^10.101
```

### Deploy the StrongSwan service

Create the pre-shared key:
```
$ sudo om system/sec/strongswan create
$ sudo om system/sec/strongswan key add --name psk --value "$(openssl rand -base64 32)"
```

Store the strongSwan configuration, the same for every node:
```
$ sudo om system/cfg/strongswan create
$ sudo om system/cfg/strongswan key add --name swanctl.conf --from https://raw.githubusercontent.com/opensvc/opensvc_templates/main/strongswan/swanctl.conf
$ sudo om system/cfg/strongswan key add --name strongswan.conf --from https://raw.githubusercontent.com/opensvc/opensvc_templates/main/strongswan/strongswan.conf
```

`swanctl.conf` is a template: it ranges over the tunnels of the node, and reads
the pre-shared key from `system/sec/strongswan`. It selects the `ipip` and
`ip6ip6` tunnel traffic, the protocols `4` and `41`: with
`network#backendnet.tunnel_mode=gre`, select `47` instead.

Deploy the strongswan service:
```
$ sudo om system/svc/strongswan create --config https://raw.githubusercontent.com/opensvc/opensvc_templates/main/strongswan/osvc.strongswan.conf --provision --wait
```

After a few seconds, you should see an up and running service:

```
user@node1:~$ sudo om system/svc/strongswan instance ls
OBJECT                 NODE   AVAIL
system/svc/strongswan  node1  up
system/svc/strongswan  node2  up
system/svc/strongswan  node3  up
```

Each node renders its own peers: on node1, the rendered configuration has a
connection named `node2` and one named `node3`, with the tunnel endpoints as
their addresses.

```
user@node1:~$ sudo cat /srv/strongswan.system.svc.<clustername>/swanctl.conf
```

The tasks run on the events of their node (columns abridged):

```
user@node1:~$ sudo om system/svc/strongswan schedule list
OBJECT                 NODE   ACTION  KEY                     ...  ON                      PACE
system/svc/strongswan  node1  run     task#load_all.schedule  ...  FileInstalled,rid=fs#1  @10s
system/svc/strongswan  node1  run     task#refresh.schedule   ...  NetworkPeersUpdated     @30s backoff @1m
```

The connections are negotiated on the first packet a tunnel carries. Once some
traffic flowed, list them in the container:

```
user@node1:~$ sudo docker exec system..strongswan.container.swanctl swanctl --list-sas
```

## Operate

### Rotate the pre-shared key

```
$ sudo om system/sec/strongswan key change --name psk --value "$(openssl rand -base64 32)"
```

Every node renders the configuration again with the new key, and strongSwan
loads it. The connections established keep their keys until they are
negotiated again, the new ones use the new pre-shared key.

### Add or remove a node

Nothing to do: the other nodes render the tunnel to a node joining as soon as it
is in the cluster nodes, and drop the one to a node leaving, and the instance of
a new node renders all its tunnels when it starts.

## Test

### Deploy a test service on each nodes

```
$ sudo om pod1 create --provision \
  --kw nodes=node1 \
  --kw orchestrate=ha \
  --kw container#1.type=oci \
  --kw container#1.image=ghcr.io/opensvc/pause \
  --kw container#1.rm=true \
  --kw ip#1.type=netns \
  --kw ip#1.network=backendnet \
  --kw ip#1.netns=container#1

$ sudo om pod2 create --provision \
  --kw nodes=node2 \
  --kw orchestrate=ha \
  --kw container#1.type=oci \
  --kw container#1.image=ghcr.io/opensvc/pause \
  --kw container#1.rm=true \
  --kw ip#1.type=netns \
  --kw ip#1.network=backendnet \
  --kw ip#1.netns=container#1

$ sudo om pod3 create --provision \
  --kw nodes=node3 \
  --kw orchestrate=ha \
  --kw container#1.type=oci \
  --kw container#1.image=ghcr.io/opensvc/pause \
  --kw container#1.rm=true \
  --kw ip#1.type=netns \
  --kw ip#1.network=backendnet \
  --kw ip#1.netns=container#1
```

### Test inter-service communications

Get the IP from the services you created with:
```
$ sudo om net ip list
OBJECT    NODE    RID   IP                           NET_NAME     NET_TYPE
pod1      node1   ip#1  10.101.0.14                  backendnet   routed_bridge
pod2      node2   ip#1  10.101.1.79                  backendnet   routed_bridge
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

On the other node (node1):

```
# ipv4
nsenter --net=`docker inspect pod1.container.1 | jq -r .[0].NetworkSettings.SandboxKey` ping 10.101.1.79

# ipv6
nsenter `...` ping6 ...
```

### Common issues

#### Packets are transmitted and received (0% packet loss)

Check if the packets are transmitted as plain tunnel traffic instead of ESP:
```
# ipv4 (ipip)
$ sudo tcpdump -i br-prd ip proto 4

# ipv6 (ip6ip6)
$ sudo tcpdump -i br-prd ip6 proto 41
```

If the tunnel packets are seen unencrypted, check the connections strongSwan
loaded (`swanctl --list-conns` in the container), the rendered
`swanctl.conf`, and the `task#load_all` runs in `om system/svc/strongswan logs`.

#### All packets are lost (100% packet loss)

- Make sure your nodes can communicate without any VPN tunnel and service and if they can recheck your nodes configuration and services configuration and make sure all the IPs and CIDRs are correct. It can also be due to firewall, ip rules...
- The tunnels and IKE need the protocols `4` or `41`, and `50` (ESP), and the udp ports `500` and `4500`, allowed between the nodes.
- With IPv6, check ip6 firewall tables.

The DROP forward policy is a very common blocker.
```
$ sudo ip6tables -L
...
Chain FORWARD (policy DROP)
...
```

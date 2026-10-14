# Heartbeat relay

## Template generations

| Generation | Minimum OpenSVC version | Minimum grant to deploy | Network |
| --- | --- | --- | --- |
| [v2](v2/README.md) | v3.0.0-rc49 | admin of the namespace | an address of a cluster network, backend or lan, deployable without the root grant |
| v1, this page | v3 | root: a host path mount, and an address of the node's choosing | a cni address, or an address of the node's interface |

The files of a generation stay at their url, working with the agents it
requires: a change needing a newer agent comes as a new generation, in a
directory of its own. Use the newest generation your agents support.

The rest of this page is the v1 howto.

# Requirements

- **CNI** installed
- **Docker** installed
- **OpenSVC** latest version

# Deploy the relay secrets

```
om system/sec/relay-v3 create
om system/sec/relay-v3 add --key users/myusername --value mypassword
```

# Deploy the relay service

```
om system/svc/relay-v3 deploy --config https://raw.githubusercontent.com/opensvc/opensvc_templates/main/relay-v3/relay-v3-ip-cni.conf
```

# Options

### Deploy with custom network configuration 

```
om system/svc/relay-v3 deploy --config https://raw.githubusercontent.com/opensvc/opensvc_templates/main/relay-v3/relay-v3.conf --env public_iface=eth0 --env ip_name=192.168.1.100 --env gateway=192.168.1.1 --env netmask=255.255.0.0
```

### Use your own certs

Import your certs in the host secret:

```
om system/sec/relay-v3 add --key ssl/private_key --from /uri/to/private/key
om system/sec/relay-v3 add --key ssl/certificate_chain --from /uri/to/certificate/chain
```

### Custom listener port

Custom the relay-v3 listener port in the host secret:

```
om system/sec/relay-v3 add --key cluster/listener.port --value 1215
```

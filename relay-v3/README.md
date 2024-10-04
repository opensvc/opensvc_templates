# Requirements

- **CNI** installed
- **Docker** installed
- **Relay-v3** container image
- **OpenSVC** lastest version

# Deploy the relay secrets

```
om system/sec/relay-v3 create
om system/sec/relay-v3 add --key users/myusername --value mypassword
```

# Deploy the relay service

**Note**: You can find how to build the relay-v3 container image here: https://github.com/opensvc/docker_osvc_relay-v3

```
om system/svc/relay-v3 create
om system/svc/relay-v3 deploy --config https://raw.githubusercontent.com/opensvc/opensvc_templates/main/relay-v3/relay-v3.conf
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

### Custom cluster name

Custom the relay-v3 cluster name in the host secret:

```
om system/sec/relay-v3 add --key cluster/cluster.name --value toto
```

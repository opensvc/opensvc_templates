# NFS Templates

This directory provides two high-availability NFS server configurations for OpenSVC.

## 1. Host-Based NFS Server (nfsv4.conf)

A traditional NFS v4 server running directly on the host with OpenSVC HA orchestration.

This configuration is preferred where robustness and efficiency prevail.

**Features:**
- NFS v4 only (v2/v3 disabled)
- TCP only
- Dedicated NFS host IP via `{env.nfshost}`
- Shared root filesystem at `{env.rootfs}` (typically `/srv/{fqdn}`)
- Integrated with nfsdcld for NFSv4 client tracking
- Uses `init.nfsd` script for service management

**Components:**
- `ip#1`: Host-based IP for NFS service
- `fs#1`: ext4 root filesystem with required NFS directories
- `fs#2-4`: Bind mounts for NFS configuration
- `app#1-4`: NFS daemons (nfsdcld, rpc.idmapd, nfsd, rpc.mountd)

**Deploy**
```
om test/svc/nfsv4 deploy \
    --config https://raw.githubusercontent.com/opensvc/opensvc_templates/main/nfs/nfsv4.conf \
    --env dev=/dev/mapper/36001405ded28414e2ea4c248008e6af1 \
    --env nfshost=nfsv4.opensvc.com
```

## 2. Containerized NFS Server (nfsv4-container.conf)

A containerized NFS server using OCI containers with OpenSVC HA orchestration.

**Features:**
- NFS server running in OCI container (`docker.io/erichough/nfs-server`)
- Container network namespace with MACVLAN
- Shared data volume for NFS exports (`/nfsroot`)
- Configuration volumes for `exports` and `nfs.conf`
- Debug container for troubleshooting
- Optional `nfsv4-container-disabled.conf` variant with NFS container disabled

**Components:**
- `ip#1`: NetNS IP address with MACVLAN
- `volume#cfg`: Shared memory volume for configuration files
- `volume#data`: Data volume for NFS exports
- `container#0`: Pause container for network namespace
- `container#debug`: Toolbox container for debugging
- `container#nfs`: NFS server container
- `task#export`: Command to reload exports

**Environment Variables:**
```
nfsimage = docker.io/erichough/nfs-server
size = 10G
fqdn = nfsv4.acme.com
nic = eth0
gateway = 10.11.12.13
```


Requirements
* CNI installed
* docker or podman installed
* OpenSVC agent 2.1+ installed

Create the registry.opensvc.com credential secret.

```
docker login -u <email> registry.opensvc.com
om test/sec/creds-registry-opensvc-com create
om test/sec/creds-registry-opensvc-com add --from ~/.docker/config.json
```

Create the certificate for nginx.

```
om test/sec/collector create
om test/sec/collector gen cert
```

Create the configmap to host the nginx.conf content.

```
om test/cfg/collector create
om test/cfg/collector add --key nginx.conf --from https://github.com/opensvc/opensvc_templates/blob/main/collector/nginx.conf
```

Deploy the collector service.
```
om test/svc/collector deploy --config https://github.com/opensvc/opensvc_templates/blob/main/collector/collector.conf
```

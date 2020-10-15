Requirements
* CNI installed
* docker or podman installed
* OpenSVC agent 2.1+ installed

Create a secret to host the ssl certificate for nginx and db password.

```
om test/sec/collector create
om test/sec/collector gen cert
om test/sec/collector add --key db_password --value opensvc
```

Create a configmap to host the nginx configuration.

```
om test/cfg/collector create
om test/cfg/collector add --key nginx.conf --from https://github.com/opensvc/opensvc_templates/blob/main/collector/nginx.conf
```

Deploy the collector service.
```
om test/svc/collector deploy --config https://github.com/opensvc/opensvc_templates/blob/main/collector/collector.conf
```

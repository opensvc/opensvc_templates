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
curl -o- -s https://raw.githubusercontent.com/opensvc/opensvc_templates/main/collector/nginx.conf | om test/cfg/collector add --key nginx.conf```
```

Deploy the collector service.
```
om test/svc/collector deploy --config https://raw.githubusercontent.com/opensvc/opensvc_templates/main/collector/collector.conf
```

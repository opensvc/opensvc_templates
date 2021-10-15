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

Create a configmap to host the nginx configuration and admin scripts.

```
om test/cfg/collector create
curl -o- -s https://raw.githubusercontent.com/opensvc/opensvc_templates/main/collector/nginx.conf | om test/cfg/collector add --key nginx.conf --from -
curl -o- -s https://raw.githubusercontent.com/opensvc/opensvc_templates/main/collector/scripts/dbdump.sh | om test/cfg/collector add --key dbdump.sh --from -
curl -o- -s https://raw.githubusercontent.com/opensvc/opensvc_templates/main/collector/scripts/dbdump.tables | om test/cfg/collector add --key dbdump.tables --from -
```

Deploy the collector service.
```
om test/svc/collector deploy --config https://raw.githubusercontent.com/opensvc/opensvc_templates/main/collector/collector.conf
```

Display service information.
```
om test/svc/collector print status -r
```

All items should be up and green coloured.

Open your favorite browser and point to `https://<ip.of.service>` using the ip displayed in the print status output

Collector web portal credentials
* login: `root@localhost.localdomain`
* password: `opensvc`


A task is scheduled every day to dump the database on a local volume.
You can run it manually using 

```
om test/svc/collector run --rid task#dbdump
```

Cleanup (data loss !) can be done using the command below
```
om 'test/*/*' purge
```

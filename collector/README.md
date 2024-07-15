Requirements
* CNI installed
* docker or podman installed
* OpenSVC agent 2.1+ installed

***

Create a secret to host the ssl certificate for nginx, git projet url (may contain access token) and db password.

First set namespace and service name as environment variables:
```
export NS=infra
export SVC=collector
```

Then start deployment

```
om $NS/sec/$SVC create
om $NS/sec/$SVC gen cert
om $NS/sec/$SVC add --key db_password --value opensvc
om $NS/sec/$SVC add --key CUSTO_WEB2PY_ADMIN_CONSOLE_PWD --value S3Cr3t
om $NS/sec/$SVC add --key repo --value https://github.com/opensvc/collector
```

With a private git clone, to circumvent github access denial,
```
om $NS/sec/$SVC change --key repo --value https://username:<personal access token>@lab.my.corp/opensvc/collector
```

***

Create a configmap to host the nginx configuration and admin scripts.

```
om $NS/cfg/$SVC create
curl -o- -s https://raw.githubusercontent.com/opensvc/opensvc_templates/main/collector/nginx.conf | om $NS/cfg/$SVC add --key nginx.conf --from -
curl -o- -s https://raw.githubusercontent.com/opensvc/opensvc_templates/main/collector/scripts/dbdump.sh | om $NS/cfg/$SVC add --key dbdump.sh --from -
curl -o- -s https://raw.githubusercontent.com/opensvc/opensvc_templates/main/collector/scripts/dbrestore.sh | om $NS/cfg/$SVC add --key dbrestore.sh --from -
curl -o- -s https://raw.githubusercontent.com/opensvc/opensvc_templates/main/collector/scripts/dbdump.tables | om $NS/cfg/$SVC add --key dbdump.tables --from -
```

***

Deploy the collector service.
```
om $NS/svc/$SVC deploy --config https://raw.githubusercontent.com/opensvc/opensvc_templates/main/collector/collector.conf
```

***

Display service information.
```
om $NS/svc/$SVC print status -r
```

All items should be up and green coloured.

***

Connect to the web interface

Open your favorite browser and point to `https://<ip.of.service>` using the ip displayed in the print status output

Collector web portal credentials
* login: `root@localhost.localdomain`
* password: `opensvc`

***

A task is scheduled every day to dump the database on a local volume.
You can run it manually using 

```
om $NS/svc/$SVC run --rid task#dbdump
```

***

Another task can be used to restore a database dump
It has to be executed manually, and asks for operator confirmation

```
om $NS/svc/$SVC run --rid task#dbrestore
```

**Warning** data loss expected, be sure that it is what you expect before running this task

***

Cleanup (service + data loss !) can be done using the command below
```
om "$NS/*/*" purge
```


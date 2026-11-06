# oc3 collector

| Minimum OpenSVC version | Minimum grant to deploy |
| --- | --- |
| v3.0.0-rc59 | admin of the namespace |

oc3, the OpenSVC collector: the OpenSVC agents of your clusters send it their
status, their actions and their inventory, and it keeps them in a database,
with a web interface to browse, search and report on them.

Deployed in a namespace of your own, it needs no root grant, and nothing from
the cluster configuration but the `default` network.

## How it works

* `<ns>/sec/oc3` holds the passwords of the database, random ones the service
  generates when it is first provisioned, and the certificate oc3 is served
  with.
* `<ns>/cfg/oc3` holds the oc3 configuration, what creates the database at its
  first start (the schema and the data of the collector, and a script setting
  the password of oc3 on it), and the configuration of nginx. The service creates it, and fetches each of these
  keys from its url when it is missing: a key there already is kept, your own
  version of it included.
* `<ns>/svc/oc3` installs them in a volume, takes an address from a cluster
  network, and runs in containers sharing it:
  * the database (mariadb) and redis, reached on 127.0.0.1 only;
  * `migrate`, bringing the schema of the database up to the version of oc3,
    at each start;
  * the feeder, which the agents post to, and the server, the api the agents
    and the web interface use, on 127.0.0.1 only;
  * the workers, the scheduler and the messenger, at work behind them;
  * nginx, the one way in, over https on port 443 alone: the web interface,
    its api, and the feeder and the server for the agents, under `/feeder/`
    and `/server/`. Nothing leaves the service in clear, a gateway in front
    or not;
  * a dump of the databases each night, the last three kept in the volume.

## Deploy

Create the sec with a certificate, named after the address the agents and
the browsers use, self-signed unless the sec names a `ca` (see Certificate and
gateway). The passwords of the database, the service generates in it:

```
$ om ns1/sec/oc3 create --kw cn=oc3.example.com --kw alt_names=oc3.example.com
$ om ns1/sec/oc3 certificate create
```

Deploy the service, on the cluster network the agents and the browsers reach
it through:

```
$ om ns1/svc/oc3 deploy --config https://raw.githubusercontent.com/opensvc/opensvc_templates/main/oc3/oc3.conf \
    --kw ip#1.network=default \
    --kw volume#1.size=4g \
    --wait
```

The volume holds the database and the files the agents upload: size it for
your fleet, in a pool of the cluster with the room for it.

Its first start fetches the keys the cfg lacks, then creates the database, a
minute or two. The address taken is the one of `ip#1`:

```
$ om ns1/svc/oc3 instance status -r
```

The `om` commands above can be `ox` ones, from a workstation.

## Sign in

Open `https://<the address>`, and sign in as `root@localhost.localdomain`,
password `opensvc`. Change this password at once, in the user menu.

## Connect the agents

On each cluster sending its data to oc3, point the agents at it, and register
each node with the credentials of a user of oc3 allowed to:

```
$ om cluster config update --set collector.url=https://<the address>
$ om node register --app <app> --credential /path/to/credential
```

The agents check the certificate of oc3 against the certificate authorities
their system trusts: serve oc3 with a certificate one of them signed, a public
or a company one, on oc3 or on a gateway in front (see Certificate and
gateway). A self-signed certificate they refuse.

The credential file holds `<username>:<password>`. A node registered, its
cluster joined by new nodes registers them as they join.

## Options

### Versions and upgrades

The template runs the latest release of oc3 `0.3`, as a node pulls it: a node
pulls an image once, when it does not have it, so a node pulling later may run
a newer patch release than the others. To run the same release everywhere, set
the exact one, as `0.3.18`. Move to a newer version by changing the tag, which
the nodes pull as they start it:

```
$ om ns1/svc/oc3 config update --set env.oc3_image=ghcr.io/opensvc/oc3:<version>
$ om ns1/svc/oc3 restart
```

`migrate` brings the database up to the new version as oc3 starts. Back the
database up first: `om ns1/svc/oc3 task run dbdump`.

The web interface is one gzipped file in the volume, `/web/html/index.html.gz`,
fetched from the latest oc3-frontend release when the service was deployed,
and following the volume from node to node. Move to another release by its
url: the next start fetches it, the url changed:

```
$ om ns1/svc/oc3 config update --set env.web_url=https://github.com/opensvc/oc3-frontend/releases/download/<version>/index.html.gz
$ om ns1/svc/oc3 restart
```

### Back up and restore

`task#dbdump` dumps the databases each night, between 05:30 and 06:00, to
`/dumps/oc3.<time>.sql.gz` in the volume, and keeps the last three: change
`env.dump_retention` to keep more. Copy them out of the volume, to keep them
past its loss. Dump now:

```
$ om ns1/svc/oc3 task run dbdump
```

To restore, stop oc3, run `task#dbrestore`, which asks for a confirmation,
and start oc3 again: `migrate` brings the schema restored up to the version
of oc3. It restores `/dumps/restore.me.sql.gz` when there is one, else the
latest dump.

```
$ om ns1/svc/oc3 instance stop --subset oc3
$ om ns1/svc/oc3 task run dbrestore --confirm
$ om ns1/svc/oc3 instance start
```

What was written to the database since the dump is lost.

### Certificate and gateway

oc3 is served with the `certificate_chain` and the `private_key` of the sec:
`certificate create` writes them, or add your own, a certificate your agents and
browsers trust, and restart the web container:

```
$ om ns1/sec/oc3 key change --name certificate_chain --from /path/to/chain.pem
$ om ns1/sec/oc3 key change --name private_key --from /path/to/key.pem
$ om ns1/svc/oc3 restart --rid container#web
```

`certificate create` signs with the certificate authority the `ca` keyword of the sec
names, a sec of the same namespace for an admin of it, or self-signs. A gateway
in front of oc3, as the ingress gateway templates of this repository, keeps it
encrypted to the end, its hop to oc3 crossing the network of the cluster:

* passing TLS through, routed on the server name: oc3 serves its own
  certificate, the one the agents and the browsers check;
* or opening TLS again to oc3: the gateway serves the public certificate, and
  checks the one of oc3 against the authority that signed it.

### Single sign-on

oc3 signs users in through an OpenID Connect provider. Add the client secret
to the sec, have the containers read it, and add the `server.oidc` settings to
`config.yaml` in the cfg:

```
$ om ns1/sec/oc3 key add --name oidc_client_secret --value '<the client secret>'
$ om ns1/svc/oc3 config update --set 'container#server.environment+=OC3_SERVER_OIDC_CLIENT_SECRET from ./sec/{name} key oidc_client_secret'
$ om ns1/cfg/oc3 key edit --name config.yaml
$ om ns1/svc/oc3 restart
```

```
server:
  addr: 127.0.0.1:8081
  oidc:
    enable: true
    display_name: <the provider>
    issuer: https://<the provider>/
    client_id: <the client id>
    redirect_url: https://<the oc3 address>/api/auth/callback
    post_logout_redirect_url: https://<the oc3 address>/
    scopes: [openid, email, profile]
    link_by_verified_email: true
```

Its session cookie is secure, which the https of the web interface allows.

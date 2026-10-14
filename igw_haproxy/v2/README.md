# HAProxy Ingress Gateway, with zeroconf certificates

| Minimum OpenSVC version | Minimum grant to deploy |
| --- | --- |
| v3.0.0-rc49 | root: the public address is named, with its interface, netmask and gateway |

Every node needs this version: the gateway installs its routes and the
certificates of its domains with install lines, one naming the secs of the
domains by a pattern, removes the files of the routes and domains gone, and
obtains the certificates with an acme task reading the domains from the
routes, which earlier agents do not have.

A failover service running haproxy on a public address, routing the requests
of the outside world to the services of the cluster. Its certificates follow
its routes: adding a route for a domain obtains a certificate for it, from an
ACME directory as Let's Encrypt, with nothing else to do, the certificate is
renewed before it expires, and removed with the last route of the domain.

## How it works

Three objects of the same name, here in the `system` namespace:

* `system/cfg/haproxy`: the haproxy configuration, the head in `haproxy.cfg`,
  and the routes, one key each under `conf.d/`, named after the domain they
  serve.
* `system/svc/haproxy`: the service, installing the cfg and the secs in a
  memory volume, running haproxy in a container, and obtaining the
  certificates with `task#acme`.
* `system/sec/haproxy`: the default certificate, which haproxy presents to a
  client asking no domain of the routes. The service creates it, self-signed,
  at its first start.

And a sec per domain of the routes, `system/sec/haproxy-<domain>`, which
`task#acme` creates and deletes: the volume installs the certificate of each in
the `certs/` directory haproxy reads them from, as `certs/<domain>.pem`.

```
[task#acme]
type = acme
secs = ./sec/{name}
directory = {env.acme_directory}
email = {env.acme_email}
domains_from = volume#1:/haproxy/conf.d/*.cfg
domains_to = ./sec/{name}-*
webroot = volume#1:/haproxy/acme-challenges
on = FileInstalled,rid=volume#1
schedule = @1d
```

A route is a key `conf.d/<domain>.cfg`, holding a backend named after the
domain: the https frontend of the head sends the request for a host to the
backend named as that host. When the routes change, the volume installs them
again, haproxy reloads, and the task runs, for each `conf.d/<domain>.cfg`:

* a domain whose dns record points to an address of the service gets its sec,
  and its certificate from the ACME directory, which proves the domain
  through the http frontend serving the challenge tokens. The certificate is
  renewed when due.
* a domain pointing elsewhere, or not resolving yet, is pending: it gets its
  certificate at the first run after its record points to the gateway. The
  task fails while a domain is pending, which its status and
  `om daemon exec list` show, and a run from the command line says which.
* the sec of a domain no route names any longer is deleted, and its
  certificate removed from haproxy.

The secs of the domains share one account at the directory, as a directory
limits the accounts an address registers. The task also runs daily, for the
renewals and the domains whose record changed. A certificate per domain fails
alone: a domain whose record points elsewhere does not hold the others back.

## Deploy

Choose the public address of the gateway, which the dns records of the domains
will point to.

### The configuration

```
$ sudo om system/cfg/haproxy create
$ sudo om system/cfg/haproxy key add --name haproxy.cfg --from https://raw.githubusercontent.com/opensvc/opensvc_templates/main/igw_haproxy/v2/haproxy.cfg
$ sudo om system/cfg/haproxy key add --name acme-http01-webroot.lua --from https://raw.githubusercontent.com/opensvc/opensvc_templates/main/igw_haproxy/v2/acme-http01-webroot.lua
$ sudo om system/cfg/haproxy key add --name conf.d/README --from https://raw.githubusercontent.com/opensvc/opensvc_templates/main/igw_haproxy/v2/conf.d-README
```

### The service

Try the setup out against the staging directory of Let's Encrypt first:

```
$ sudo om system/svc/haproxy create --config https://raw.githubusercontent.com/opensvc/opensvc_templates/main/igw_haproxy/v2/osvc.haproxy.conf \
    --kw env.acme_directory=letsencrypt-staging \
    --kw env.acme_email=admin@example.com \
    --kw env.backend_network=backend \
    --kw env.public_addr=203.0.113.10 \
    --kw env.public_netmask=24 \
    --kw env.public_gateway=203.0.113.1 \
    --kw env.public_dev=br-prd \
    --provision --wait
```

* `acme_directory` is the ACME directory the certificates are obtained from,
  `letsencrypt` by default, and `acme_email` the contact of the account there,
  which may be left empty.
* `backend_network` is the cluster network the backends are reached through.
* `public_*` is the public address, on the bridge `public_dev` of the nodes,
  which the dns records of the domains point to.

Once the staging certificates are in place, switch to the directory browsers
trust: the next run obtains the certificates of every domain from it.

```
$ sudo om system/svc/haproxy config update --set env.acme_directory=letsencrypt
$ sudo om system/svc/haproxy instance run --rid task#acme
```

## Add a route

As a key of its own, named after the domain:

```
$ cat www.example.com.cfg
backend www.example.com
    server www www.ns1.svc.${CLUSTERNAME}:8080 resolvers clusterdns check init-addr none

$ sudo om system/cfg/haproxy key add --name conf.d/www.example.com.cfg --from www.example.com.cfg
```

Point the dns record of `www.example.com` to the public address: its
certificate is obtained at the next run of the task, at the latest the next
day, or right away with:

```
$ sudo om system/svc/haproxy instance run --rid task#acme
```

A route can also be written in `haproxy.cfg` itself, or as an explicit rule,
`use_backend be_x if { hdr(host) -i x }`. Its domain then gets a certificate
from an empty key named after it, `conf.d/<domain>.cfg`.

A key under `conf.d/` can also hold a frontend of its own, as a tcp one, with
its bind and its backends. Only the keys ending in `.cfg` are read by haproxy,
and only the ones named after a domain get a certificate.

## Remove a route

Remove its key: the route is removed from haproxy right away, the file of the
key being removed with it, and the sec of the domain is deleted, with its
certificate.

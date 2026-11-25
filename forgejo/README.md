# forgejo

| Minimum OpenSVC version | Minimum grant to deploy |
| --- | --- |
| v3.0.0-rc71 | admin of the namespace |

A step by step tutorial: you will run [Forgejo](https://forgejo.org), a git
forge, on your OpenSVC cluster, with its database and a runner for its
actions, the CI of the forge. Your users push their repositories there, open
issues and pull requests, and the workflows of their repositories run on the
runner.

The forge moves from node to node with its repositories and its database:
when it moves, your users connect again to the same name and see the same
forge, and the runner follows.

## What you need

* An OpenSVC v3 cluster, v3.0.0-rc71 or later on every node, with docker or
  podman on the nodes, and the cluster dns (`system/svc/dns`).
* The `om` command, on a node of the cluster. The commands of this tutorial
  run as root there (`sudo om ...`), or as the admin of the namespace, with
  `om` or `ox` from your workstation.
* A cluster network your users can reach, to take the addresses of the
  service from. This tutorial takes `default`, which a cluster always has:
  its addresses are reached from the node running the service only, right for
  a test. For users out of the cluster, take a network they are routed to.
* A volume pool shared between the nodes, a `drbd` one for example, for the
  repositories and the database to follow the forge from node to node.
  `sudo om pool ls` lists the pools: a shared one has `shared` in its
  capabilities.
* The nodes reach `data.forgejo.org`, `docker.io` and `ghcr.io`, for the
  images, and the jobs reach `data.forgejo.org`, for the actions they use.

## How it works

Three objects, in a namespace of your choice, `demo` in this tutorial, all
named `forgejo`:

* `demo/svc/forgejo`, the service, running two pods, each with an address
  taken from the cluster network, and each in a subset of its own, to act on
  it alone:
  * the server pod, subset `server`, `server.forgejo.demo.svc.<clustername>`,
    its containers named after the order they start in:
    * `container#0pod`, the pod: it holds the address, `ip#1`;
    * `container#1db`, the postgres database, only listening inside the pod;
    * `container#2forgejo`, the forge, on port 3000 for the web and the
      api, and port 22 for git over ssh;
    * `container#3init`, run once at each start: it makes the admin
      account, and registers the runner;
  * the runner pod, subset `worker`, `runner.forgejo.demo.svc.<clustername>`:
    * `container#4pod`, the pod: it holds the address, `ip#2`;
    * `container#5dind`, the docker engine the jobs run on, only listening
      inside the pod: the jobs never see the engine of the node;
    * `container#6runner`, the forgejo runner: it asks the forge for jobs,
      and runs them on `container#5dind`;
  * `volume#1`, shared between the nodes, following the forge: the
    database, the data of the forge, what the service installs from the
    cfg, and the cache of the runner pod, the images of the jobs and the
    clones of the actions. Its `install` lines make its directories, the one
    of the runner owned by the user it runs as.
* `demo/cfg/forgejo`, a configmap: the scripts of the service, and
  `runner-config.yml`, the configuration of the runner, which you can edit.
  The service adds them when it is first deployed, from this repository.
* `demo/sec/forgejo`, a secret: the password of the database, the one of the
  admin account, and the secret the runner and the forge share. The service
  makes them when it is first deployed.

```
  subset server: server pod, ip#1     subset worker: runner pod, ip#2
  +-------------------------------+    +-------------------------------+
  | 0pod     pause                |    | 4pod     pause                |
  | 1db      127.0.0.1:5432       |    | 5dind    127.0.0.1:2375       |
  | 2forgejo :3000 :22 <------------------ 6runner                    |
  | 3init    one shot             |    |    +--> the job containers    |
  +-------------------------------+    +-------------------------------+
  volume forgejo-data: /conf /data/{db,forgejo} /cache/{docker,runner}
```

The volume, `demo/vol/forgejo-data`, keeps:

```
/conf/            the scripts and the runner-config.yml of the cfg
/data/db/         the database
/data/forgejo/    the forge: repositories, app.ini, lfs, ssh host keys
/cache/docker/    the images of the jobs
/cache/runner/    the clones of the actions, the cache of the workflows
```

`/data` is what to back up. `/cache` is fetched again when missing.

The runner gets jobs from every repository of the forge, with the `docker`
and `ubuntu-latest` labels: a job runs in a `node:24-trixie` container, on
the engine of the runner pod.

## Deploy

### 1. Deploy the service

```
sudo om demo/svc/forgejo deploy --config https://raw.githubusercontent.com/opensvc/opensvc_templates/main/forgejo/forgejo.conf \
    --env network=default \
    --kw volume#1.size=10g \
    --wait
```

* `network`: the cluster network the addresses of both pods are taken from.
* `volume#1.size`: the room for the repositories, the database, and the
  cache of the runner, the images of the jobs first. The volume is taken
  from a shared pool of the cluster: add `--kw volume#1.pool=<pool>` to
  choose which, when there are several.

The first start pulls the images: count a few minutes. Check it is up, and
read the addresses, on the `ip#1` (server) and `ip#2` (runner) lines:

```
sudo om demo/svc/forgejo instance status -r
```

```
demo/svc/forgejo                       up
└ instances
  ├ node2                              down  idle
  └ node1                              up    idle started
    └ resources
      ├ subset#ip:server
      │ └ ip#1               ...../..  up    netns default 10.22.41.138/16 in container#0pod
      ├ subset#ip:worker
      │ └ ip#2               ...../..  up    netns default 10.22.39.215/16 in container#4pod
      ├ volume#1             ........  up    forgejo-data
      ├ subset#container:server
      │ ├ container#0pod     ...../..  up    docker ghcr.io/opensvc/pause
      │ ├ container#1db      ...../.3  up    docker docker.io/library/postgres:18.7-alpine
      │ ├ container#2forgejo ...../.3  up    docker data.forgejo.org/forgejo/forgejo:17.0.2
      │ └ container#3init    ...../..  n/a   docker data.forgejo.org/forgejo/forgejo:17.0.2
      └ subset#container:worker
        ├ container#4pod     ...../..  up    docker ghcr.io/opensvc/pause
        ├ container#5dind    ...../.3  up    docker docker.io/library/docker:29.10.0-dind
        └ container#6runner  ...../.3  up    docker data.forgejo.org/forgejo/runner:13.2.2
```

The forge runs on one node, `node1`, the other node standing by.
`container#3init` has done its job and is gone: `n/a` is its normal state.
Its logs say what it did:

```
sudo om demo/svc/forgejo container logs 3init
```

### 2. Sign in

The forge answers on `http://server.forgejo.demo.svc.<clustername>:3000/`,
the address of `ip#1`. Your users resolve this name with the cluster dns;
from a node, without it, use the address. Sign in as `forgejo-admin`, with
the password the service made:

```
sudo om demo/sec/forgejo key decode --name adminpassword
```

Registration is closed: the admin makes the accounts of the users, in the
site administration of the web interface.

### 3. Run a first workflow

In the web interface, make a repository with a README, and add the file
`.forgejo/workflows/demo.yml`:

```yaml
on: [push]
jobs:
  demo:
    runs-on: docker
    steps:
      - uses: actions/checkout@v4
      - run: cat README.md
```

The `Actions` tab of the repository shows the run, then its success, and the
logs of each step. The site administration, in `Actions` > `Runners`, shows
the runner of the service, `forgejo`, idle between jobs.

### 4. Move the forge to the other node

Move it, as a failure of its node would:

```
sudo om demo/svc/forgejo switch --to <the other node> --wait
```

Connect again: the same name, the same repositories, the same runs. The pods
take new addresses on the other node: the name follows them. Push a commit:
the runner, moved too, runs its workflow.

## Day to day

### See what happens

The logs of each container, on the node the service runs on (`-f` to follow
them):

```
sudo om demo/svc/forgejo container logs 2forgejo
sudo om demo/svc/forgejo container logs 6runner
```

### Restart a pod

`--subset` acts on the resources of one pod, the other one running on:

```
sudo om demo/svc/forgejo restart --subset server
sudo om demo/svc/forgejo restart --subset worker
```

Restarting the runner pod stops the running jobs: its engine keeps the
images of the jobs, in `volume#1`. Restarting the server pod leaves the
runner waiting for the forge, then taking jobs again.

### Change the runner configuration

`runner-config.yml` is a key of the cfg: the labels, the image of the jobs,
the number of jobs at once (`capacity`). Edit it, then restart the runner,
which reads it as it starts:

```
sudo om demo/cfg/forgejo key edit --name runner-config.yml
sudo om demo/svc/forgejo restart --rid container#6runner
```

### Upgrade forgejo

Read the release notes of the new version first: a forge upgrade updates the
database, and does not go back. Then set the image, and restart the forge:

```
sudo om demo/svc/forgejo config update --set env.forgejo_image=data.forgejo.org/forgejo/forgejo:<version>
sudo om demo/svc/forgejo restart --rid container#2forgejo,container#3init
```

The other images are `env.runner_image`, `env.dind_image` and `env.db_image`.
A new major version of postgres needs a dump and a restore of the database:
do not change it in place.

## Remove the service

```
sudo om demo/svc/forgejo purge --wait
```

`purge` removes the service, and leaves its volume, `demo/vol/forgejo-data`,
with the repositories and the database, and the cfg and the sec: deploy again,
and the forge is back as it was. When you need them no more, remove them too:

```
sudo om demo/vol/forgejo-data purge --wait
sudo om demo/cfg/forgejo delete
sudo om demo/sec/forgejo delete
```

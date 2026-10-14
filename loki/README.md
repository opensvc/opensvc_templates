| Minimum OpenSVC version | Minimum grant to deploy |
| --- | --- |
| v2.1-448 | root: the `sync#i0` section |

# Requirements

* CNI installed
* docker or podman installed

# Deploy the loki service.

```
om mon/cfg/loki create
om mon/cfg/loki add --key local-config.yaml --from https://raw.githubusercontent.com/opensvc/opensvc_templates/main/loki/local-config.yaml
om mon/svc/loki deploy --config https://raw.githubusercontent.com/opensvc/opensvc_templates/main/loki/loki.conf
```


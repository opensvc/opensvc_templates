| Minimum OpenSVC version | Minimum grant to deploy |
| --- | --- |
| v2.1-448 | root: the host network namespace, and an app resource |

# Requirements

* CNI installed
* docker or podman installed
* OpenSVC dns service installed

# Deploy the sozu service.

```

om mon/cfg/sozu create
om mon/cfg/sozu add --key config.toml --from https://raw.githubusercontent.com/opensvc/opensvc_templates/main/sozu/config.toml
om mon/cfg/sozu add --key watch_directory.sh --from https://raw.githubusercontent.com/opensvc_templates/main/sozu/watch_directory.sh
om mon/svc/sozu deploy --config https://raw.githubusercontent.com/opensvc/opensvc_templates/main/sozu/sozu.conf
```





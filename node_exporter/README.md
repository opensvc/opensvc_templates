| Minimum OpenSVC version | Minimum grant to deploy |
| --- | --- |
| v2.1-448 | root: the host network namespace, and host path mounts |

# Requirements

* docker or podman installed

# Deploy the nodeexporter service.

```
om mon/svc/nodeexp deploy --config https://raw.githubusercontent.com/opensvc/opensvc_templates/main/node_exporter/nodeexporter.conf
```


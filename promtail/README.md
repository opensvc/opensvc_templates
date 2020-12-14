# Requirements

* CNI installed
* docker or podman installed
* OpenSVC agent 2.1-448+ installed
* Loki service deployed (https://github.com/opensvc/opensvc_templates/tree/main/loki)
* OpenSVC dns service installed (promtail is configured to push to http://loki:3100/loki/api/v1/push)

# Deploy the promtail service.

```
om mon/cfg/promtail create
om mon/cfg/promtail add --key promtail-docker-config.yaml --from https://raw.githubusercontent.com/opensvc/opensvc_templates/main/promtail/promtail-docker-config.yaml
om mon/svc/promtail deploy --config https://raw.githubusercontent.com/opensvc/opensvc_templates/main/promtail/promtail.conf
```


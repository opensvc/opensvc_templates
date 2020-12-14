# Requirements

* CNI installed
* docker or podman installed
* OpenSVC agent 2.1-448+ installed
* OpenSVC dns service installed
* Red Hat Quay.io node exporter installed

# Deploy the prometheus service.

```
om mon/cfg/prometheus create
om mon/cfg/prometheus add --key prometheus.yml --from https://raw.githubusercontent.com/opensvc/opensvc_templates/main/prometheus/prometheus.yml
om mon/svc/prometheus deploy --config https://raw.githubusercontent.com/opensvc/opensvc_templates/main/prometheus/prometheus.conf
```


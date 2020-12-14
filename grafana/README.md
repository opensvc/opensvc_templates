# Requirements

* CNI installed
* docker or podman installed
* OpenSVC agent 2.1-448+ installed
* OpenSVC dns service installed
* Loki or/and Prometheus data source available (see datasources.yaml)

# Deploy the grafana secret to store login credentials (admin/grafana)

```
om mon/sec/grafana create
om mon/sec/grafana add --key grafana_user --value admin
om mon/sec/grafana add --key grafana_password --value grafana
```

# Deploy the grafana configmap to store configuration parameters

```
om mon/cfg/grafana create
om mon/cfg/grafana add --key datasources.yaml --from https://raw.githubusercontent.com/opensvc/opensvc_templates/main/grafana/datasources.yaml
om mon/cfg/grafana add --key dashboards.yaml --from https://raw.githubusercontent.com/opensvc/opensvc_templates/main/grafana/dashboards.yaml
om mon/cfg/grafana add --key node-exporter.json --from https://raw.githubusercontent.com/opensvc/opensvc_templates/main/grafana/node-exporter.json
```

# Deploy the grafana service.

```
om mon/svc/grafana deploy --config https://raw.githubusercontent.com/opensvc/opensvc_templates/main/grafana/grafana.conf
```


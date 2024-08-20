# Requirements

* CNI installed
* docker or podman installed
* OpenSVC agent 2.1-448+ installed
* OpenSVC dns service installed

# Deploy the hdoc service.

---

om mon/cfg/hdoc create
om mon/cfg/hdoc add --key local-config.yaml --from https://raw.githubusercontent.com/opensvc/opensvc_templates/main/hdoc/local-config.yaml
om mon/svc/hdoc deploy --kw volume#1.shared=true --config https://raw.githubusercontent.com/opensvc/opesvc_templates/main/hdoc/hdoc.conf
---

Alternatively, you can choose to set volume#1.shared=false if you want to provision a single instance fortest purpose.

# Official hedgedoc documentation

You can find more configuration options on https://docs.hedgedoc.org/configuration/

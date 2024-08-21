# Requirements

* CNI installed
* docker or podman installed
* OpenSVC agent 2.1-448+ installed
* OpenSVC dns service installed

# Deploy the hdoc service.

---

om test/cfg/hdoc create
om test/cfg/hdoc add --key config.json --from https://raw.githubusercontent.com/opensvc/opensvc_templates/main/hedgedoc/config.json
om test/svc/hdoc deploy --kw volume#1.shared=false --config https://raw.githubusercontent.com/opensvc/opensvc_templates/main/hedgedoc/hdoc.conf
---

Alternatively, you can choose to set volume#1.shared=true if you are provisioning on a multi-node cluster with a pool that can create shared volumes.

# Official hedgedoc documentation

You can find more configuration options on https://docs.hedgedoc.org/configuration/

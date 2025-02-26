Deploy a HA cluster virtual ip address in a cluster.
This ip address is useful to access the OpenSVC agent API on any available node.

    om system/svc/vip deploy \
        --config https://raw.githubusercontent.com/opensvc/opensvc_templates/main/vip/vip.conf \
        --kw ip#0.name=192.168.1.1 \
        --kw ip#0.netmask=24 \
        --kw ip#0.dev=br-prd

Note this template is made for om3 only.

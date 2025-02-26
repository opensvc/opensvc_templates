This template can be deploy to add a HA cluster virtual ip address to a cluster.
This ip address is useful to access the OpenSVC agent API on any available node.

    om system/svc/vip deploy \
        --config https://raw.githubusercontent.com/opensvc/opensvc_templates/main/vip/vip.conf \
        --kw ip#0.address=192.168.1.1 \
        --kw ip#0.netmask=24 \
        --kw ip#0.interface=br-prd

Note this template is made for om3 only.

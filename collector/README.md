om test/sec/collector create
om test/sec/collector gen cert

om test/cfg/collector create
om test/cfg/collector add --key nginx.conf --from https://github.com/opensvc/opensvc_templates/blob/main/collector/nginx.conf

om test/svc/collector deploy --config https://github.com/opensvc/opensvc_templates/blob/main/collector/collector.conf

# Deploy a basic haproxy

    # Create the frontend TLS certificate
    sudo om testigw/sec/haproxy create
    sudo om testigw/sec/haproxy gencert

    # Create a haproxy configuration as a cfg key
    sudo om testigw/cfg/haproxy create
    sudo om testigw/cfg/haproxy add --key haproxy.cfg --from https://raw.githubusercontent.com/opensvc/opensvc_templates/main/igw_haproxy/basic-cfg-haproxy.cfg

    # Deploy the Ingress Gateway svc
    sudo om testigw/svc/haproxy deploy --config https://raw.githubusercontent.com/opensvc/opensvc_templates/main/igw_haproxy/basic-svc.conf


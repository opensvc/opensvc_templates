# Deploy a basic haproxy

    # Create the frontend TLS certificate
    sudo om testigw/sec/haproxy create
    sudo om testigw/sec/haproxy gen cert

    # Create a haproxy configuration as a cfg key
    sudo om testigw/cfg/haproxy create
    sudo om testigw/cfg/haproxy add --key haproxy.cfg --from https://raw.githubusercontent.com/opensvc/opensvc_templates/main/igw_haproxy/basic/basic-cfg-haproxy.cfg

    # Deploy the Ingress Gateway svc
    sudo om testigw/svc/haproxy deploy --config https://raw.githubusercontent.com/opensvc/opensvc_templates/main/igw_haproxy/basic/basic-svc.conf

# Deploy a haproxy with ACME

This configuration demonstrate a https frontend routing to 2 different backends the servernames `s[12].opensvc.org`.
The frontend uses 2 certificates obtained from a ACME compliant provider, using the acme.sh client and renew daemon.

    # Create the frontend default TLS certificate
    sudo om testigw/sec/haproxy create
    sudo om testigw/sec/haproxy gen cert

    # Create a haproxy configuration as a cfg key
    sudo om testigw/cfg/haproxy create
    sudo om testigw/cfg/haproxy add --key haproxy.cfg --from https://raw.githubusercontent.com/opensvc/opensvc_templates/main/igw_haproxy/acme/acme-cfg-haproxy.cfg

    # Add the LUA ACME challenge responder script to the cfg
    sudo om testigw/cfg/haproxy add --key acme-http01-webroot.lua --from https://raw.githubusercontent.com/opensvc/opensvc_templates/main/igw_haproxy/common/acme-http01-webroot.lua

    # Deploy the Ingress Gateway svc
    sudo om testigw/svc/haproxy deploy --config https://raw.githubusercontent.com/opensvc/opensvc_templates/main/igw_haproxy/acme/acme-svc.conf

# Issuing certificates

    # For every TLS server name
    sudo om testigw/svc/haproxy run --rid task#issuecert --env domain=s1.opensvc.org

Once issued and deployed, a cronjob will daily renew the expiring certificate.

# Public access

Note these templates don't include a public ip address.

Example public address setup:

    sudo om testigw/svc/haproxy set \
        --kw ip#0.type=netns \
        --kw ip#0.name=10.20.30.40 \
        --kw ip#0.dev=br-prd \
        --kw ip#0.gateway=10.20.30.1 \
        --kw ip#0.netmask=24 \
        --kw ip#0.netns=container#0


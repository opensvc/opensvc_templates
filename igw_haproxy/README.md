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

# Deploy a haproxy with ACME and splitted config

This configuration demonstrate a https frontend routing solution made for automated haproxy config updates and ssl cert creation.

    # Create the frontend default TLS certificate
    sudo om testigw/sec/haproxy create
    sudo om testigw/sec/haproxy gen cert

    # Create a haproxy configuration as cfg keys
    sudo om testigw/cfg/haproxy create
    sudo om testigw/cfg/haproxy add --key haproxy.cfg
    sudo om testigw/cfg/haproxy add --key haproxy.cfg.temp
    sudo om testigw/cfg/haproxy add --key haproxy.cfg.head --from https://raw.githubusercontent.com/opensvc/opensvc_templates/main/igw_haproxy/acme-config-split/acme-split-cfg-haproxy-head.cfg
    sudo om testigw/cfg/haproxy add --key gencfg.sh --from https://raw.githubusercontent.com/opensvc/opensvc_templates/main/igw_haproxy/acme-config-split/gencfg.sh

    # Add the LUA ACME challenge responder script to the cfg
    sudo om testigw/cfg/haproxy add --key acme-http01-webroot.lua --from https://raw.githubusercontent.com/opensvc/opensvc_templates/main/igw_haproxy/common/acme-http01-webroot.lua

    # Deploy the Ingress Gateway svc
    sudo om testigw/svc/haproxy deploy --config https://raw.githubusercontent.com/opensvc/opensvc_templates/main/igw_haproxy/acme-config-split/acme-svc-split-config.conf

# Haproxy dynamic configuration

Splitted haproxy config rely on opensvc configmap keys.

By convention, we use the service fqdn backend name as key name.

    root@node1:~# om daemon dns dump | grep graylog
    10-60-0-82.graylog.monitor.svc.default.      IN   A      60  10.60.0.82
    graylog.graylog.monitor.svc.default.         IN   A      60  10.60.0.82
    graylog.monitor.svc.default.                 IN   A      60  10.60.0.82
    graylog.monitor.svc.node1.node.default.      IN   A      60  10.60.0.82

As graylog is listening on port 9000, we will use `haproxy.cfg.d/graylog.monitor.svc.default_9000` as key name

    sudo om testigw/cfg/haproxy add --key haproxy.cfg.d/graylog.monitor.svc.default_9000

Then we have to edit the key to fill with the correct configuration

    sudo om testigw/cfg/haproxy edit --key haproxy.cfg.d/graylog.monitor.svc.default_9000

The haproxy configuration snippet to add is below

    frontend https
        use_backend graylog.monitor.svc.default_9000 if { hdr(host) -i graylog.example.com }

    backend graylog.monitor.svc.default_9000
        server-template srv 1 graylog.monitor.svc.default:9000 resolvers cluster check init-addr none

Please note that the frontend is already declared in the `haproxy.cfg.head` key.

DNS record `graylog.example.com` has to be configured to point to the haproxy service public ip 

As an example, another config snippet with a syslog L4 tcp forward from haproxy to graylog, to be created in the `haproxy.cfg.d/graylog.monitor.svc.default_514` key

    frontend graylog_tcp_514
        bind *:514
        mode tcp
        use_backend graylog.monitor.svc.default_514

    backend graylog.monitor.svc.default_514
        mode tcp
        server-template graylog 1 graylog.monitor.svc.default:514 resolvers cluster check init-addr none


# Issuing certificates

Certificates are generated automatically by the `gencfg.sh` script. It iterates over all haproxy keys, match `hdr(host)` expression, and then extracts all fqdn that need to be added to the certificate.

Creating a new certificate is as simple as creating a new key as seen previously, and then running the opensvc task `task#mergecfg`

    sudo om testigw/svc/haproxy run --rid task#mergecfg

The task will build the new haproxy.cfg file, generate new certs is needed, do a haproxy config validation check, and if successfull will notify haproxy to reload with the new configuration.

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

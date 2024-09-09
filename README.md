# opensvc_templates

This project contains templates for the OpenSVC infrastructure services:

* collector

  The OpenSVC site-wide infrastructure information collector and reporting server.
  
* dns

  The in-cluster nameserver serving the backend networks ip addresses of services.
  
* igw_envoy

  The envoy-based cluster ingress gateway service.
  
* pod

  A container hosting service skeleton : fs.flag, ip.cni from the default backend network, and google/pause container.

* hedgedoc

  A template used to deploy the hedgedoc markdown collaborative editor.

* grafana

  A template for quickly deploying and configuring Grafana.

* igw_gobetween

  The gobetween_based cluster ingress gateway service.

* nfs

  A template for setting up an NFS server and configuring network file sharing for clients.

* prometheus
  
  A template for deploying and configuring Prometheus for monitoring and alerting in a cluster environment.

* loki

  A template for setting up and configuring Loki to aggregate and visualize logs in a cluster environment.

* node_exporter

  A template for deploying and configuring Node Exporter to collect and expose system metrics in a cluster environment.

* promtail

  A template for deploying and configuring Promtail to collect and forward logs to Loki in a cluster environment.

* mdadm

  A template for setting up and configuring mdadm to manage and maintain RAID arrays in a Linux environment.

* sozu

  A template for deploying and configuring Sozu as a high-performance HTTP reverse proxy and load balancer.

* guacamole

 A template for deploying Guacamole as a connection manager.

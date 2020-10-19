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
  

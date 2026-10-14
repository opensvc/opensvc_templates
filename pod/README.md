| Minimum OpenSVC version | Minimum grant to deploy |
| --- | --- |
| v2.1 | root: the `sync#i0` section, and a filesystem |

Requirements
* CNI installed
* docker or podman installed

Deploy.
```
om test/svc/pod deploy --config https://raw.githubusercontent.com/opensvc/opensvc_templates/main/pod/pod.conf
```

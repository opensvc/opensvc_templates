# Requirements

* CNI installed
* docker installed
* OpenSVC agent 2.1-448+ installed
* OpenSVC dns service installed

# Deploy

```
om guacamole create
om sec/guacamole add --key dbuser --value example_user
om sec/guacamole add --key dbpassword --value example_password
om cfg/guacamole add --key pg_dumpall.bash --from https://raw.githubusercontent.com/opensvc/opensvc_templates/main/guacamole/pg_dumpall.bash
om guacamole deploy --config https://raw.githubusercontent.com/opensvc/opensvc_templates/main/guacamole/guacamole.conf
```

# Documentation

You can find how to configure Apache Guacamole on https://guacamole.apache.org/doc/gug/introduction.html


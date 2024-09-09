# Requirements

* CNI installed
* docker installed
* OpenSVC agent 2.1-448+ installed
* OpenSVC dns service installed
* OpenTofu Installed

# Deploy

```
om guacamole create
om sec/guacamole add --key dbuser --value example_user
om sec/guacamole add --key dbpassword --value example_password
om cfg/guacamole add --key pg_dumpall.bash --from https://raw.githubusercontent.com/opensvc/opensvc_templates/main/guacamole/pg_dumpall.bash
om guacamole deploy --config https://raw.githubusercontent.com/opensvc/opensvc_templates/main/guacamole/guacamole.conf
```
# Configuration

To install the Guacamole provider, we will first create a working directory that will contain our configuration for Tofu and the future configuration files for the Guacamole web client.

Once in this directory, we can create a file named `provider.tf` that contains the following code:

```bash
terraform {
  required_providers {
    guacamole = {
      source = "desotech-it/guacamole"
      version = "1.2.10"
    }
  }
}

provider guacamole {
  url = "http://guacamole.example.com:8080/guacamole"
  username = "guacadmin"
  password = "guacadmin"
}
```

In this file we specify to OpenTofu that we use the guacamole provider from desotech-it and we give him access to our web client. 

You can run `tofu init` to initialize our OpenTofu project directory.

From here, we will set up a training environment. Each student will have access to three machines within his own cluster (lab). For this example, there will be only one student. The instructor will have an admin account and will be able to access both his own lab environment and the students labs.

We need a cluster with three machines for the student and another one for the instructor.

Here you can find the provider documentation for additional information: https://library.tf/providers/desotech-it/guacamole/latest

We will establish the connections in `training_cnx.tf`:

```bash
# Create local variables to shorten the name of our connection groups identifiers (don't worry we will create them later) 
locals {
  env01id = guacamole_connection_group.CNXGRPenv01.id
  env02id = guacamole_connection_group.CNXGRPenv02.id
  env03id = guacamole_connection_group.CNXGRPenv03.id
}

# An example of how to declare a connection:
resource "guacamole_connection_ssh" "c1n1" {
  name = "c1n1"
  parent_identifier = local.env01id
  parameters {
    hostname = "training.example.com"
    username = "student"
    private_key = var.ssh_student_private_key
    port = 20111
    disable_copy = true
    color_scheme = "green-black"
    font_size = 14
    timezone = "Europe/Paris"
    # Guacamole is very sensitive to the name of your recording directory and record name. Therefore, you should use `{HISTORY_PATH}` as the recording directory and ensure that the record name includes `{HISTORY_UUID}`.
    typescript_path = "$\n{HISTORY_PATH}/c1n1_$\n{GUAC_DATE}_$\n{GUAC_TIME}_$\n{HISTORY_UUID}"
    typescript_name = "c1n1_typescript"
    recording_path = "$\n{HISTORY_PATH}/c1n1_$\n{GUAC_DATE}_$\n{GUAC_TIME}_$\n{HISTORY_UUID}"
    recording_name = "c1n1_screen"
    recording_auto_create_path = true
  }
}

resource "guacamole_connection_ssh" "c1n2" {
  name = "c1n2"
  parent_identifier = local.env01id
  parameters {
    hostname = "training.example.com"
    username = "student"
    private_key = var.ssh_student_private_key
    port = 20112
    disable_copy = true
    color_scheme = "green-black"
    font_size = 14
    timezone = "Europe/Paris"
    typescript_path = "$\n{HISTORY_PATH}/c1n2_$\n{GUAC_DATE}_$\n{GUAC_TIME}_$\n{HISTORY_UUID}"
    typescript_name = "c1n2_typescript"
    recording_path = "$\n{HISTORY_PATH}/c1n2_$\n{GUAC_DATE}_$\n{GUAC_TIME}_$\n{HISTORY_UUID}"
    recording_name = "c1n2_screen"
    recording_auto_create_path = true
  }
}

resource "guacamole_connection_ssh" "c1n3" {
  name = "c1n3"
  parent_identifier = local.env01id
  parameters {
    hostname = "training.example.com"
    username = "student"
    private_key = var.ssh_student_private_key
    port = 20113
    disable_copy = true
    color_scheme = "green-black"
    font_size = 14
    timezone = "Europe/Paris"
    typescript_path = "$\n{HISTORY_PATH}/c1n3_$\n{GUAC_DATE}_$\n{GUAC_TIME}_$\n{HISTORY_UUID}"
    typescript_name = "c1n3_typescript"
    recording_path = "$\n{HISTORY_PATH}/c1n3_$\n{GUAC_DATE}_$\n{GUAC_TIME}_$\n{HISTORY_UUID}"
    recording_name = "c1n3_screen"
    recording_auto_create_path = true
  }
}

resource "guacamole_connection_ssh" "c10n1" {
  name = "c10n1"
  parent_identifier = local.env10id
  parameters {
    hostname = "training.example.com"
    username = "instructor"
    private_key = var.ssh_instructor_private_key
    port = 21011
    disable_copy = true
    color_scheme = "green-black"
    font_size = 14
    timezone = "Europe/Paris"
    typescript_path = "$\n{HISTORY_PATH}/c10n1_$\n{GUAC_DATE}_$\n{GUAC_TIME}_$\n{HISTORY_UUID}"
    typescript_name = "c10n1_typescript"
    recording_path = "$\n{HISTORY_PATH}/c10n1_$\n{GUAC_DATE}_$\n{GUAC_TIME}_$\n{HISTORY_UUID}"
    recording_name = "c10n1_screen"
    recording_auto_create_path = true
  }
}

resource "guacamole_connection_ssh" "c10n2" {
  name = "c10n2"
  parent_identifier = local.env10id
  parameters {
    hostname = "training.example.com"
    username = "instructor"
    private_key = var.ssh_instructor_private_key
    port = 21012
    disable_copy = true
    color_scheme = "green-black"
    font_size = 14
    timezone = "Europe/Paris"
    typescript_path = "$\n{HISTORY_PATH}/c10n2_$\n{GUAC_DATE}_$\n{GUAC_TIME}_$\n{HISTORY_UUID}"
    typescript_name = "c10n2_typescript"
    recording_path = "$\n{HISTORY_PATH}/c10n2_$\n{GUAC_DATE}_$\n{GUAC_TIME}_$\n{HISTORY_UUID}"
    recording_name = "c10n2_screen"
    recording_auto_create_path = true
  }
}

resource "guacamole_connection_ssh" "c10n3" {
  name = "c10n3"
  parent_identifier = local.env10id
  parameters {
    hostname = "training.example.com"
    username = "instructor"
    private_key = var.ssh_opensvc_private_key
    port = 21013
    disable_copy = true
    color_scheme = "green-black"
    font_size = 14
    timezone = "Europe/Paris"
    typescript_path = "$\n{HISTORY_PATH}/c10n3_$\n{GUAC_DATE}_$\n{GUAC_TIME}_$\n{HISTORY_UUID}"
    typescript_name = "c10n3_typescript"
    recording_path = "$\n{HISTORY_PATH}/c10n3_$\n{GUAC_DATE}_$\n{GUAC_TIME}_$\n{HISTORY_UUID}"
    recording_name = "c10n3_screen"
    recording_auto_create_path = true
  }
}
```

To use the same configuration with private key contained in a variable, follow these steps.

Declare your variable in the `variables.tf` file:

```
variable "ssh_student_private_key" {
  description = "The SSH private key to be used for SSH connections via opensvc user"
  type        = string
  sensitive   = true
}
```

Add the content of the variable, in this case the SSH private key, to the `terraform.tfvars` file:

```
ssh_student_private_key = <<EOF
-----BEGIN OPENSSH PRIVATE KEY-----

your_ssh_private_key

-----END OPENSSH PRIVATE KEY-----
EOF
```

Our key is now saved in a variable.

You can now proceed to run `tofu validate` to check your syntax.

Create the connection groups in `training_cnxgroups.tf` as follows:

```bash
# Use a local variable to streamline the use of this connection group identifier.
locals {
  trainingid = guacamole_connection_group.trainingCourseCNXGroup.id
}

# Declare this connection group and the others using the following syntax:
resource "guacamole_connection_group" "trainingCourseCNXGroup" {
  parent_identifier = "ROOT"
  name = "trainingCourseCNXGroup"
  type = "organizational"
  attributes {
    max_connections_per_user = 4
  }
}

resource "guacamole_connection_group" "CNXGRPenv01" {
  parent_identifier = local.trainingid
  name = "CNXGRPenv01"
  type = "organizational"
  attributes {
    max_connections_per_user = 4
  }
}

resource "guacamole_connection_group" "CNXGRPenv10" {
  parent_identifier = local.trainingid
  name = "CNXGRPenv10"
  type = "organizational"
  attributes {
    max_connections_per_user = 4
  }
}
```

Create your user groups in the file `training_usergroups.tf` :

```bash
# Local variables for referencing our connections and connection groups
locals {
  cnxgrptrainingid = guacamole_connection_group.trainingCourseCNXGroup.id
  cnxgrpenv01id = guacamole_connection_group.CNXGRPenv01.id
  cnxenv01c1n1id = guacamole_connection_ssh.c1n1.id
  cnxenv01c1n2id = guacamole_connection_ssh.c1n2.id
  cnxenv01c1n3id = guacamole_connection_ssh.c1n3.id
  cnxenv10c10n1id = guacamole_connection_ssh.c10n1.id
  cnxenv10c10n2id = guacamole_connection_ssh.c10n2.id
  cnxenv10c10n3id = guacamole_connection_ssh.c10n3.id
}

# Here we declare a user group that utilizes connection and connection group identifiers to assign them to the group.
resource "guacamole_user_group" "trainingCourseUserGroup" {
  identifier = "trainingCourseUserGroup"
  connections = [
    local.cnxenv01c1n1id, local.cnxenv01c1n2id, local.cnxenv01c1n3id,
    local.cnxenv10c10n1id, local.cnxenv10c10n2id, local.cnxenv10c10n3id
  ]
  connection_groups = [
    local.cnxgrptrainingid,
    local.cnxgrpenv01id,
    local.cnxgrpenv10id
  ]
  attributes {
    disabled = false
  }
}

resource "guacamole_user_group" "UserGroupenv01" {
  identifier = "UserGroupenv01"
  connections = [
    local.cnxenv01c1n1id, local.cnxenv01c1n2id, local.cnxenv01c1n3id
  ]
  connection_groups = [
    local.cnxgrptrainingid,
    local.cnxgrpenv01id
  ]
  attributes {
    disabled = false
  }
}

resource "guacamole_user_group" "UserGrouposvc" {
  identifier = "UserGrouposvc"
  connections = [
    local.cnxenv10c10n1id, local.cnxenv10c10n2id, local.cnxenv10c10n3id
  ]
  connection_groups = [
    local.cnxgrptrainingid,
    local.cnxgrpqaid,
  ]
  attributes {
    disabled = false
  }
}
```

Create your users in the file `training_users.tf`:

```bash
# Use local variables to reference our user group identifiers.
locals {
  trainingusergroupid = guacamole_user_group.trainingCourseUserGroup.id
  osvcusergroupid = guacamole_user_group.UserGrouposvc.id
  group01id = guacamole_user_group.UserGroupenv01.id
}

# Proceed to create our users.
resource "guacamole_user" "student01" {
  username = "student01"
  password = "password"
  attributes {
    full_name = "Student_01"
  }
  group_membership = [local.group01id]
}

resource "guacamole_user" "instructor" {
  username = "instructor"
  password = "password"
  attributes {
    full_name = "Instructor"
  }
  group_membership = [local.trainingusergroupid, local.osvcusergroupid]
}
```

If you haven't made any syntax errors, you can now run the `tofu plan` command to review the modifications you've made.

Once everything is in order, you can run `tofu apply` and check your Guacamole web interface to view the new configuration.

**Note**: To remove your Guacamole configuration, you can use the `tofu destroy` command.

Here it is, we've configured our connections with OpenTofu, and it was much more efficient than doing it manually through the web portal.

# Documentation

You can find how to configure Apache Guacamole on https://guacamole.apache.org/doc/gug/introduction.html

Here is the official documentation for OpenTofu: https://opentofu.org/docs/

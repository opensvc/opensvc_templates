Requirements
* OpenSVC agent 2.1+ installed
* mdadm
* 4 block devices (d1, d2, d3, d4). need to be shared between cluster nodes.

Summary
* this example shows mdadm driver usage
* d1 and d2 are mirrored (md12)
* d3 and d4 are mirrored (md34)
* md12 and md34 are assembled in raid0
* a lvm vg is created on top of raid0 device
* a lv is created in lvm vg to make an ext4 filesystem

Deploy.
```
om test/svc/md create --config https://raw.githubusercontent.com/opensvc/opensvc_templates/main/mdadm/mdadm.conf
om test/svc/md set --kw env.devs="/dev/mapper/3601... /dev/mapper/3602...  /dev/mapper/3603... /dev/mapper/3604..." --kw env.size=20G
om test/svc/md provision
```

# icinga2-disaster-recovery
Scripts for promoting an Icinga 2 secondary master to config master

**This is a very early version for a very specific usecase** Please do not use in production

The current version of the scripts will only work with an Icinga 2 Master pair. One config-master will be backupped. When this config master is lost you can use the backuptarball to promote the second master to master.

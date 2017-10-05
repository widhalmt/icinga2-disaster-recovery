#!/bin/bash
# script for creating automated disaster recovery tarballs for icinga 2
# author: Thomas Widhalm <thomas.widhalm@netways.de>
# version: 0.1

# known limitations #
# * does not check if director is even used
# * needs .my.cnf file with password
# * leaves temporary directories
# * director module hast to be present at second master

BUDIR=$(mktemp -d --tmpdir ic2_dr.XXXXXX)
BUTIMESTAMP=$(date +%Y-%m-%d_%H%M)

echo "### starting icinga 2 disaster recovery backup ###"
echo "### run on ${hostname} at ${BUTIMESTAMP} ###"

#if [ -d ${BUDIR} ]
#then
#  echo "### backup directory exists ###"
#else
#  echo "### creating backup directory ###"
#  mkdir -p ${BUDIR}
#fi

echo "run on ${hostname} at ${BUTIMESTAMP}" > ${BUDIR}/timestamp

echo "### dumping director database ###"

/usr/bin/mysqldump director --add-drop-database > ${BUDIR}/director.sql

echo "### backup CA ###"

cp -a /var/lib/icinga2/ca ${BUDIR}/

echo "### collecting configuration ### "

grep TicketSalt /etc/icinga2/constants.conf > ${BUDIR}/ticketsalt

# copy scripts to have custom notification scripts, eventhandler, etc.
cp -a /etc/icinga2/scripts ${BUDIR}/

# use the synchronized version at /var/lib/icinga2/api/zones on the other node
# if possible. This is just a backup
tar cf ${BUDIR}/zones_d.tar /etc/icinga2/zones.d

# features are often node-specific. backup them just in case
tar cf ${BUDIR}/features.tar /etc/icinga2/features*

echo "### collecting director config ###"

DIRECTOR_RESOURCE=$(grep ^resource /etc/icingaweb2/modules/director/config.ini | cut -d\" -f2)

grep -ozP "(?s)\[${DIRECTOR_RESOURCE}.*?^$" /etc/icingaweb2/resources.ini > ${BUDIR}/director_resource

cp -a /etc/icingaweb2/modules/director ${BUDIR}/

cp -a /etc/icingaweb2/roles.ini ${BUDIR}/

echo "### building tarball ###"

tar cjf icinga2_disasterrecovery_${BUTIMESTAMP}.tar.bz2 -C ${BUDIR} . 
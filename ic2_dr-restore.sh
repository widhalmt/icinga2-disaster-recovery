#!/bin/bash
# script for importing automated disaster recovery tarballs for icinga 2
# author: Thomas Widhalm <thomas.widhalm@netways.de>
# version: 0.1

# known limitations #
# * no handling of permissions
# * creates some temporary and backupfiles (->clean up or list)
# * no errorhandling if director config is missing
# * no check if scripts are already present
# * error handling is minimalistic (better version did not work)
# * does not handle features

RDIR=$(mktemp -d --tmpdir ic2_dr.XXXXXX)

# improve error handling
tar xf ${1} -C ${RDIR} || exit 1

cd ${RDIR}

echo "### restore Director database ###"
mysql -e "CREATE DATABASE director CHARACTER SET 'utf8';"
mysql director < director.sql
DIRECTORPW=$(grep password director_resource | cut -d\" -f2)
mysql -e "GRANT ALL ON director.* TO director@localhost IDENTIFIED BY '${DIRECTORPW}';"

echo "### restore CA ###"

cp -a ca /var/lib/icinga2/

echo "### create backuptarball of current configuration ###"

tar czf ~/icinga2_configuration$(date +%Y-%m-%d).tgz /etc/icinga2
tar czf ~/icingaweb2_configuration$(date +%Y-%m-%d).tgz /etc/icingaweb2

echo "### restore ticketsalt ###"

cat /etc/icinga2/constants.conf > /etc/icinga2/constants.dr_backup
grep -v TicketSalt /etc/icinga2/constants.dr_backup > /etc/icinga2/constants.conf
cat ticketsalt >> /etc/icinga2/constants.conf

echo "### restore scripts ###"

cp -a scripts/* /etc/icinga2/scripts/

echo "### restore director resource ###"

if [ -f /etc/icingaweb2/modules/director/config.ini ]
then
  echo "#** director database configuration exists **#"
else
  echo "### restoring director connection ###"
  cp -a director /etc/icingaweb2/modules/director/
  echo "" >> /etc/icingaweb2/resources.ini
  cat director_resource >> /etc/icingaweb2/resources.ini
fi

# move every zone except director-global to local configuration directory
# "director-global" is hardcoded in director and can be used for filtering
# only "etc" part is to be copied. director part will be redeployed
for i in $(ls /var/lib/icinga2/api/zones/ | grep -v director-global)
do
  if [ -d /var/lib/icinga2/api/zones/$i/_etc/ ]
  then
    echo "### move zone $i to configuration directory ###"
    mkdir -p /etc/icinga2/zones.d/$i/
    cp -a /var/lib/icinga2/api/zones/$i/_etc/* /etc/icinga2/zones.d/$i/
  fi
done

echo "### enable director module ###"

icingacli module enable director

echo "### restore Icinga Web 2 roles ###"

cp -a /etc/icingaweb2/roles.ini /etc/icingaweb2/roles.ini.dr_backup
cp -a roles.ini /etc/icingaweb2/

echo "### restarting icinga 2 ###"

systemctl restart icinga2

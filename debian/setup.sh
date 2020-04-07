#!/usr/bin/env bash
set -euxo pipefail

MAIN_USER=${MAIN_USER:-xcvb}

# 0 if exist, 1 if not
user_exist=$(id -u $MAIN_USER > /dev/null 2>&1; echo $?)

if [ $user_exist -eq "1" ]; then
  useradd --disabled-password -m $MAIN_USER
  USERHOME=/home/$MAIN_USER
  mkdir $USERHOME/.ssh
  cp ~/.ssh/authorized_keys $USERHOME/.ssh/authorized_keys
  chown -R $MAIN_USER:$MAIN_USER $USERHOME
  chmod 700 $USERHOME/.ssh
  chmod 644 $USERHOME/.ssh/authorized_keys

  su - $MAIN_USER -c 'ssh-keygen -t ed25519 -q -f "$USERHOME/.ssh/id_rsa" -N ""'
fi

REPO="https://raw.githubusercontent.com/levmorozov/devops/master"
export DEBIAN_FRONTEND="noninteractive"

wget -i - <<EOF
$REPO/debian/debian10.sh
$REPO/debian/nginx.sh
$REPO/debian/maria104.sh
$REPO/debian/php.sh
$REPO/debian/yarn.sh
$REPO/acme.sh
$REPO/dbdump.sh
EOF

chmod +x *.sh

. debian10.sh
. nginx.sh
. maria104.sh
. php.sh
. yarn.sh
. acme.sh

rm debian10.sh nginx.sh maria104.sh php.sh yarn.sh acme.sh

rm /etc/update-motd.d/*
wget -O /etc/update-motd.d/10-hostname $REPO/motd/10-hostname
wget -O /etc/update-motd.d/20-sysinfo $REPO/motd/20-sysinfo
chmod +x /etc/update-motd.d/*
rm /etc/motd

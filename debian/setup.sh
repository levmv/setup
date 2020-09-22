#!/usr/bin/env bash
set -euxo pipefail

MAIN_USER=${MAIN_USER:-xcvb}
REPO="https://raw.githubusercontent.com/levmorozov/devops/master"

export DEBIAN_FRONTEND="noninteractive"

sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sed -i -e 's/# ru_RU.UTF-8 UTF-8/ru_RU.UTF-8 UTF-8/' /etc/locale.gen
dpkg-reconfigure --frontend=noninteractive locales
update-locale LANG=ru_RU.UTF-8 LC_MESSAGES=POSIX
echo 'Europe/Moscow' | tee /etc/timezone > /dev/null
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
dpkg-reconfigure -f noninteractive tzdata

sed -i 's/#FallbackNTP/FallbackNTP/' /etc/systemd/timesyncd.conf
systemctl enable systemd-timesyncd.service && systemctl start systemd-timesyncd.service
apt-get update && apt-get dist-upgrade -y
apt-get install -y software-properties-common lsb-release apt-transport-https ca-certificates debconf-utils \
                   gnupg2 git zip unzip curl wget build-essential vim nano sudo tmux figlet procps htop apt-file \
                   python3-pip python3-dev python3-venv libssl-dev libffi-dev zstd libfcgi-bin vnstat sysstat

sed -i -e '/#SystemMaxUse=/s/#SystemMaxUse=/SystemMaxUse=200M/g' /etc/systemd/journald.conf

rm /etc/update-motd.d/*
wget -O /etc/update-motd.d/10-hostname $REPO/motd/10-hostname
wget -O /etc/update-motd.d/20-sysinfo $REPO/motd/20-sysinfo
chmod +x /etc/update-motd.d/*
rm /etc/motd

# 0 if exist, 1 if not
user_exist=$(id -u $MAIN_USER > /dev/null 2>&1; echo $?)

if [ $user_exist -eq "1" ]; then
  adduser --disabled-password --gecos "" --shell /bin/bash $MAIN_USER
  USERHOME=/home/$MAIN_USER
  mkdir -p $USERHOME/.ssh
  cp ~/.ssh/authorized_keys $USERHOME/.ssh/authorized_keys
  chown -R $MAIN_USER:$MAIN_USER $USERHOME
  chmod 700 $USERHOME/.ssh
  chmod 644 $USERHOME/.ssh/authorized_keys
  echo $USERHOME
  su - $MAIN_USER -c 'ssh-keygen -t ed25519 -q -f "'$USERHOME'/.ssh/id_rsa" -N ""'

  echo "$MAIN_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/xcvb
fi



wget -i - <<EOF
$REPO/debian/nginx.sh
$REPO/debian/maria105.sh
$REPO/debian/php.sh
$REPO/debian/yarn.sh
$REPO/acme.sh
$REPO/dbdump.sh
EOF

chmod +x *.sh

. nginx.sh
. maria105.sh
. php.sh
. yarn.sh
#. acme.sh

rm nginx.sh maria105.sh php.sh yarn.sh

apt-get autoremove -y
apt-get clean



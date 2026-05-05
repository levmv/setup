#!/usr/bin/env bash
set -euo pipefail

CN=$1
USERN=${2:-$USERN}
REPO="https://raw.githubusercontent.com/levmv/setup/master"

export DEBIAN_FRONTEND="noninteractive"

timedatectl set-timezone Europe/Moscow

sed -i -e '/#SystemMaxUse=/s/#SystemMaxUse=/SystemMaxUse=200M/g' /etc/systemd/journald.conf
systemctl restart systemd-journald

apt-get update
apt-get install -yq --no-install-recommends openssh-server apt-utils iproute2 iputils-ping dnsutils \
                   lsb-release ca-certificates debconf-utils \
                   gnupg2 git unzip curl wget build-essential nano sudo procps \
                   fd-find ripgrep \
                   python3-pip python3-venv libssl-dev libffi-dev zstd dirmngr

adduser --disabled-password --uid 1002 --gecos "" --shell /bin/bash $USERN
su - $USERN -c "ssh-keygen -t ed25519 -q -f '/home/$USERN/.ssh/id_rsa' -N ''"
install -o $USERN -g $USERN -m 644 /root/.ssh/authorized_keys /home/$USERN/.ssh/authorized_keys
echo "$USERN ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/xcvb

: > /etc/motd

ln -s /media/dev /home/$USERN/dev

# Node.js
apt-get update
apt-get install -y ca-certificates curl gnupg
mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg

NODE_MAJOR=24
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list

apt-get update
apt-get install -y nodejs

# Configure npm to install global packages as user
su - $USERN -c 'mkdir -p ~/.npm-global && npm config set prefix ~/.npm-global'
echo 'export PATH=~/.npm-global/bin:$PATH' >> /home/$USERN/.profile

# Go
apt-get install -y golang

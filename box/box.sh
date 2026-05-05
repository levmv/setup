#!/usr/bin/env bash
set -euox pipefail

CN=${1:-box}
USERN=xcvb

incus init images:debian/trixie/cloud $CN

printf "uid $(id -u) 1002\ngid $(id -g) 1002" | incus config set $CN raw.idmap -
incus config device add $CN dev disk source=$HOME/dev path=/media/dev

incus config device override $CN root size=7GB
incus config set $CN limits.memory 2GB
incus config set $CN limits.memory.enforce hard

incus start $CN

incus file push -p --uid 0 ~/.ssh/id_ed25519.pub $CN/root/.ssh/authorized_keys
incus file push ./.box_setup.sh $CN/root/

incus exec $CN -- cloud-init status --wait
incus exec $CN -- bash -c "bash /root/.box_setup.sh $CN $USERN"

incus config set $CN limits.cpu 2
incus config set $CN limits.cpu.allowance 50%

ssh-keygen -f ~/.ssh/known_hosts -R "$CN.test" || true

incus restart $CN

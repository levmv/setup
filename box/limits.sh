#!/usr/bin/env bash

lxc stop box

lxc config set box boot.autostart 1

lxc config set box raw.idmap "both $UID 1000"
lxc config device add box dev disk source=$HOME/dev path=/media/dev

lxc config set box limits.cpu 2,4
lxc config set box limits.memory 4GB
lxc config set box limits.memory.enforce hard

lxc network attach lxdbr0 box eth0 eth0
lxc config device set box eth0 ipv4.address 10.30.10.10

lxc start box
#!/usr/bin/env bash

ENCRYPTED=$1
PASSWORD=$2

if [ -z "$PASSWORD" ]; then
    echo "Usage: decbackup.sh <path/to/encrypted/file> <passphrase>\n"
    exit
fi

openssl enc -d -aes-256-cbc -md sha256 -pbkdf2 -in $1 -k $2 | gunzip
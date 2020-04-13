#!/usr/bin/env bash

DBNAME=$1
OUTPATH=$2
FILENAME=$DBNAME-`date +%F-%H%M-`$HOSTNAME".sql.zst.enc"

mysqldump --skip-quick --lock-tables $DBNAME | zstd -c -7 | openssl enc -e -aes-256-cbc -md sha256 -pbkdf2 -kfile $HOME/.backuppass > $OUTPATH/$FILENAME


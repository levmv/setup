#!/usr/bin/env bash

DBNAME=$1
OUTPATH=$2
FILENAME=$DBNAME-`date +%F-%H%M-`$HOSTNAME".sql.gz.enc"

mysqldump --quick --lock-tables $DBNAME | gzip -5 | openssl enc -e -aes-256-cbc -md sha256 -pbkdf2 -kfile $HOME/.backuppass > $OUTPATH/$FILENAME



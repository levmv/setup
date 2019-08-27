#!/usr/bin/env bash

DBNAME=$1
OUTPATH=$2
FILENAME=`date +%F-%H%M-`$HOSTNAME-$DBNAME".sql.gz.enc"

mysqldump --quick --lock-tables $DBNAME | gzip -5 | openssl enc -e -aes-256-cbc -md sha256 -pbkdf2 -kfile $HOME/.backuppass > $OUTPATH/$FILENAME



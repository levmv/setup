#!/usr/bin/env bash
set -euxo pipefail

KEY_FILE=$DOMAIN.key
CERT_FILE=$DOMAIN.crt

openssl ecparam -genkey -name prime256v1 -out $KEY_FILE
openssl req -new -SHA384 -key $KEY_FILE -nodes -out temp.csr -subj "/C=UF/ST=/O=Common sense inc./OU=Rational thinking department/CN=*.$DOMAIN"
openssl x509 -req -SHA384 -days 3650 -extfile <(printf "subjectAltName=DNS:$DOMAIN,DNS:*.$DOMAIN") -in temp.csr -CA caca.crt -CAkey caca.key -CAcreateserial -out $CERT_FILE

sudo cp $KEY_FILE /etc/nginx/certs/
sudo cp $CERT_FILE /etc/nginx/certs/

rm $KEY_FILE $CERT_FILE temp.csr

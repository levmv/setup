#!/usr/bin/env bash
set -euo pipefail

DOMAIN=${1:-${DOMAIN:-}}
[ -n "$DOMAIN" ] || {
  echo "usage: $0 DOMAIN" >&2
  exit 1
}

KEY_FILE=$DOMAIN.key
CERT_FILE=$DOMAIN.crt
CSR_FILE=$(mktemp)
FULLCHAIN_FILE=$(mktemp)
trap 'rm -f "$CSR_FILE" "$FULLCHAIN_FILE"' EXIT

openssl ecparam -genkey -name prime256v1 -out "$KEY_FILE"
openssl req -new -SHA384 -key "$KEY_FILE" -nodes -out "$CSR_FILE" -subj "/C=UF/O=Common sense inc./OU=Rational thinking department/CN=*.$DOMAIN"
openssl x509 -req -SHA384 -days 3650 -extfile <(printf "subjectAltName=DNS:%s,DNS:*.%s" "$DOMAIN" "$DOMAIN") -in "$CSR_FILE" -CA caca.crt -CAkey caca.key -CAcreateserial -out "$CERT_FILE"

cat "$CERT_FILE" caca.crt > "$FULLCHAIN_FILE"
sudo install -d -m 755 /etc/nginx/certs
sudo install -m 600 "$KEY_FILE" "/etc/nginx/certs/$KEY_FILE"
sudo install -m 644 "$FULLCHAIN_FILE" "/etc/nginx/certs/$CERT_FILE"

rm "$KEY_FILE" "$CERT_FILE"

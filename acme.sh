#!/usr/bin/env bash
set -euxo pipefail

curl https://get.acme.sh | sh
/root/.acme.sh/acme.sh --set-default-ca  --server letsencrypt
/root/.acme.sh/acme.sh --register-account --accountemail | grep ACCOUNT_THUMBPRINT | awk -F "=" '{print $2}' | tr -d \' | tee thumbprint
tee /etc/nginx/acme <<EOF
location /.well-known {
    location ~ ^/\.well-known/acme-challenge/([-_a-zA-Z0-9]+)$ {
        default_type text/plain;
        return 200 "\$1.$(cat ~/thumbprint)";
    }
}
EOF
rm thumbprint

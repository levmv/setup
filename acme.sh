#!/usr/bin/env bash
set -euxo pipefail

curl https://get.acme.sh | sh
.acme.sh/acme.sh --register-account | grep ACCOUNT_THUMBPRINT | awk -F "=" '{print $2}' | tr -d \' | sudo tee thumbprint
sudo tee /etc/nginx/acme <<EOF
location /.well-known {
    location ~ ^/\.well-known/acme-challenge/([-_a-zA-Z0-9]+)$ {
        default_type text/plain;
        return 200 "\$1.$(cat ~/thumbprint)";
    }
}
EOF

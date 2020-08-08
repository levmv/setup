#!/usr/bin/env bash


curl https://get.acme.sh | sh
.acme.sh/acme.sh --register-account | grep ACCOUNT_THUMBPRINT | awk -F "=" '{print $2}' | tr -d \' > thumbprint
cat <<EOF > /etc/nginx/acme
location /.well-known {
    location ~ ^/\.well-known/acme-challenge/([-_a-zA-Z0-9]+)$ {
        default_type text/plain;
        return 200 "\$1.$(cat /root/thumbprint)";
    }
}
EOF

#!/usr/bin/env bash

useradd -m -d /var/lib/acme -s /usr/sbin/nologin acme

cat <<EOF > /etc/sudoers.d/acme

acme    ALL=(ALL) NOPASSWD: /usr/sbin/service nginx reload
acme    ALL=(ALL) NOPASSWD: /bin/cat > /etc/nginx/acme

EOF

chmod 700 /var/lib/acme
mkdir /etc/nginx/certs 2>/dev/null
chown acme.www-data /etc/nginx/certs
chmod 710 /etc/nginx/certs

sudo -s -u acme bash <<EOF
export HOME=/var/lib/acme
cd /var/lib/acme
git clone https://github.com/Neilpang/acme.sh.git
cd acme.sh
./acme.sh --install
cd /var/lib/acme
echo "\$(.acme.sh/acme.sh --register-account | grep ACCOUNT_THUMBPRINT | awk -F "=" '{print \$2}' | tr -d \')" > thumbprint
EOF

cat <<EOF > /etc/nginx/acme

location ~ ^/\.well-known/acme-challenge/([-_a-zA-Z0-9]+)$ {
    default_type text/plain;
    return 200 "\$1.$(cat /var/lib/acme/thumbprint)";
  }

EOF
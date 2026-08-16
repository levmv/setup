#!/usr/bin/env bash
set -euo pipefail

DEBIAN_CODENAME="trixie"
PHPVER="8.4"
LEGACY_PHPVER="7.4"
PROJECT_USERS=(sts xcvb vlp)

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root." >&2
    exit 1
fi

# shellcheck source=/dev/null
. /etc/os-release
if [ "${ID:-}" != "debian" ]; then
    echo "This setup supports Debian only (found: ${ID:-unknown})." >&2
    exit 1
fi
if [ "${VERSION_CODENAME:-}" != "$DEBIAN_CODENAME" ]; then
    echo "This setup requires Debian $DEBIAN_CODENAME (found: ${VERSION_CODENAME:-unknown})." >&2
    exit 1
fi

export DEBIAN_FRONTEND="noninteractive"

create_project_user() {
    local home user

    user=$1
    if ! id -u "$user" >/dev/null 2>&1; then
        adduser --disabled-password --gecos "" --shell /bin/bash "$user"
    fi

    home=$(getent passwd "$user" | cut -d: -f6)
    chmod 711 "$home"
    install -d -o "$user" -g "$user" -m 700 "$home/.ssh"

    if [ -f /root/.ssh/authorized_keys ]; then
        install -o "$user" -g "$user" -m 600 \
            /root/.ssh/authorized_keys "$home/.ssh/authorized_keys"
    else
        echo "Warning: /root/.ssh/authorized_keys is absent; no login keys copied for $user." >&2
    fi

    if [ ! -f "$home/.ssh/id_ed25519" ]; then
        runuser -u "$user" -- ssh-keygen -t ed25519 -q \
            -f "$home/.ssh/id_ed25519" -N ""
    fi

    printf '%s ALL=(ALL) NOPASSWD:ALL\n' "$user" > "/etc/sudoers.d/$user"
    chmod 440 "/etc/sudoers.d/$user"
}

install_composer() {
    local actual_checksum expected_checksum installer

    installer=$(mktemp)
    expected_checksum=$(curl -fsSL https://composer.github.io/installer.sig)
    curl -fsSL https://getcomposer.org/installer -o "$installer"
    actual_checksum=$(php8.4 -r 'echo hash_file("sha384", $argv[1]);' "$installer")

    if [ "$expected_checksum" != "$actual_checksum" ]; then
        rm -f -- "$installer"
        echo "Invalid Composer installer checksum." >&2
        exit 1
    fi

    php8.4 "$installer" --quiet --install-dir=/usr/local/bin --filename=composer
    rm -f -- "$installer"
}

install_acme() {
    local acme installer registration thumbprint

    if [ "${SKIP_ACME:-0}" = "1" ]; then
        cat > /etc/nginx/acme <<'EOF'
location ^~ /.well-known/acme-challenge/ {
    return 404;
}
EOF
        return
    fi

    acme=/root/.acme.sh/acme.sh
    if [ ! -x "$acme" ]; then
        installer=$(mktemp)
        curl -fsSL https://get.acme.sh -o "$installer"
        sh "$installer"
        rm -f -- "$installer"
    fi

    "$acme" --set-default-ca --server letsencrypt
    if [ -n "${ACME_EMAIL:-}" ]; then
        registration=$("$acme" --register-account --accountemail "$ACME_EMAIL" 2>&1)
    else
        registration=$("$acme" --register-account 2>&1)
    fi

    thumbprint=$(printf '%s\n' "$registration" |
        sed -n "s/.*ACCOUNT_THUMBPRINT='\([^']*\)'.*/\1/p" |
        tail -n 1)
    if [ -z "$thumbprint" ]; then
        printf '%s\n' "$registration" >&2
        echo "Could not determine the ACME account thumbprint." >&2
        exit 1
    fi

    cat > /etc/nginx/acme <<EOF
location /.well-known {
    location ~ ^/\.well-known/acme-challenge/([-_a-zA-Z0-9]+)$ {
        default_type text/plain;
        return 200 "\$1.$thumbprint";
    }
}
EOF
}

initialize_mariadb() {
    local backup_password root_password

    if [ -s /root/.my.cnf ]; then
        mariadb --defaults-file=/root/.my.cnf --execute='SELECT 1' >/dev/null
        echo "Keeping existing MariaDB credentials from /root/.my.cnf."
        return
    fi

    root_password=$(openssl rand -base64 32 | tr -d '/=+')
    backup_password=$(openssl rand -base64 32 | tr -d '/=+')

    mariadb --protocol=socket --user=root <<EOF
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.user WHERE User='';
ALTER USER 'root'@'localhost' IDENTIFIED BY '$root_password';
CREATE USER IF NOT EXISTS 'backupuser'@'127.0.0.1' IDENTIFIED BY '$backup_password';
ALTER USER 'backupuser'@'127.0.0.1' IDENTIFIED BY '$backup_password';
GRANT SELECT, SHOW VIEW, TRIGGER, EVENT, LOCK TABLES ON *.* TO 'backupuser'@'127.0.0.1';
FLUSH PRIVILEGES;
EOF

    cat > /root/.my.cnf <<EOF
[client]
host=localhost
user=root
password=$root_password

[mysqldump]
host=127.0.0.1
user=backupuser
password=$backup_password
EOF
    chmod 600 /root/.my.cnf
}

apt-get update
apt-get install -yq locales
sed -i 's/^# *ru_RU.UTF-8 UTF-8/ru_RU.UTF-8 UTF-8/' /etc/locale.gen
sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
update-locale LANG=ru_RU.UTF-8 LC_MESSAGES=en_US.UTF-8
timedatectl set-timezone Europe/Moscow

install -d -m 755 /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/20-size-limit.conf <<'EOF'
[Journal]
SystemMaxUse=300M
EOF
systemctl restart systemd-journald

apt-get install -yq --no-install-recommends \
    openssh-server apt-utils iproute2 iputils-ping dnsutils cron \
    lsb-release ca-certificates debconf-utils gnupg git unzip curl wget \
    build-essential nano sudo procps htop tmux rsync jq file zstd xz-utils \
    dirmngr figlet openssl nodejs libvips42t64 libvips-tools \
    nginx mariadb-server mariadb-client

for user in "${PROJECT_USERS[@]}"; do
    create_project_user "$user"
done

rm -f /etc/update-motd.d/*
cat > /etc/update-motd.d/10-hostname <<'EOF'
#!/usr/bin/env bash
/usr/bin/env figlet "$(hostname)"
uname -snrvm
EOF
chmod 755 /etc/update-motd.d/10-hostname

# nginx base configuration. Project configurations are restored separately.
install -d -m 755 /etc/nginx/certs /etc/nginx/sites
install -d -o www-data -g www-data -m 700 /var/cache/nginx
rm -f /etc/nginx/sites-enabled/default

if [ ! -f /etc/nginx/certs/nginx.key ] || [ ! -f /etc/nginx/certs/nginx.crt ]; then
    openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
        -keyout /etc/nginx/certs/nginx.key \
        -out /etc/nginx/certs/nginx.crt \
        -subj /CN=_
    chmod 600 /etc/nginx/certs/nginx.key
    chmod 644 /etc/nginx/certs/nginx.crt
fi

cat > /etc/nginx/nginx.conf <<'EOF'
user www-data;
worker_processes auto;
worker_rlimit_nofile 4096;
pcre_jit on;
error_log /var/log/nginx/error.log warn;
pid /run/nginx.pid;

events {
    worker_connections 2048;
}

http {
    server_tokens off;
    charset utf-8;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    access_log /var/log/nginx/access.log;

    sendfile on;
    tcp_nopush on;

    keepalive_timeout 90;
    keepalive_requests 150;

    client_body_timeout 20s;
    client_header_timeout 15s;
    send_timeout 10s;
    reset_timedout_connection on;

    client_max_body_size 60m;

    gzip on;
    gzip_min_length 500;
    gzip_proxied any;
    gzip_vary on;
    gzip_types text/plain text/css application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript application/javascript image/svg+xml;
    gzip_comp_level 2;

    server {
        listen 80 default_server;
        listen 443 ssl default_server;
        server_name _;
        ssl_certificate /etc/nginx/certs/nginx.crt;
        ssl_certificate_key /etc/nginx/certs/nginx.key;
        ssl_protocols TLSv1.2 TLSv1.3;
        return 444;
    }

    server {
        listen 80;
        server_name localhost;

        location /status_page {
            stub_status on;
            allow 127.0.0.1;
            deny all;
        }
    }

    include /etc/nginx/sites/*;
}
EOF
nginx -t
systemctl enable --now nginx

# MariaDB from Debian. Application databases and users are restored separately.
systemctl enable --now mariadb
initialize_mariadb
cat > /etc/mysql/mariadb.conf.d/72-legacy-web.cnf <<'EOF'
[mysqld]
skip-name-resolve=1
max_connections=30

aria_pagecache_buffer_size=2M
key_buffer_size=2M

innodb_buffer_pool_size=256M
innodb_log_file_size=64M
EOF
systemctl restart mariadb

# packages.sury.org is needed for the PHP 7.4 runtime used by king-size33.
SURY_KEYRING_PACKAGE=$(mktemp --suffix=.deb)
curl -fsSL https://packages.sury.org/debsuryorg-archive-keyring.deb \
    -o "$SURY_KEYRING_PACKAGE"
dpkg -i "$SURY_KEYRING_PACKAGE"
rm -f -- "$SURY_KEYRING_PACKAGE"
printf 'deb [signed-by=/usr/share/keyrings/debsuryorg-archive-keyring.gpg] https://packages.sury.org/php/ %s main\n' \
    "$DEBIAN_CODENAME" > /etc/apt/sources.list.d/php.list

apt-get update
apt-get install -yq --no-install-recommends \
    "php$PHPVER-fpm" "php$PHPVER-cli" "php$PHPVER-gd" "php$PHPVER-curl" \
    "php$PHPVER-apcu" "php$PHPVER-intl" "php$PHPVER-xml" "php$PHPVER-zip" \
    "php$PHPVER-mbstring" "php$PHPVER-mysql" "php$PHPVER-ffi" \
    "php$LEGACY_PHPVER-fpm" "php$LEGACY_PHPVER-cli" \
    "php$LEGACY_PHPVER-gd" "php$LEGACY_PHPVER-curl" \
    "php$LEGACY_PHPVER-xml" "php$LEGACY_PHPVER-zip" \
    "php$LEGACY_PHPVER-mbstring" "php$LEGACY_PHPVER-mysql" \
    "php$LEGACY_PHPVER-json"

update-alternatives --set php "/usr/bin/php$PHPVER"

cat > "/etc/php/$PHPVER/fpm/conf.d/30-legacy-web.ini" <<'EOF'
memory_limit = 192M
upload_max_filesize = 60M
post_max_size = 60M
realpath_cache_size = 128k
realpath_cache_ttl = 3600
expose_php = Off
session.use_strict_mode = 1

opcache.memory_consumption = 64
opcache.validate_timestamps = 0
opcache.enable_file_override = 1
opcache.interned_strings_buffer = 8

date.timezone = Europe/Moscow
mysqlnd.collect_statistics = Off
session.cookie_samesite = Lax
ffi.enable = true
EOF

cat > "/etc/php/$PHPVER/cli/conf.d/30-legacy-web.ini" <<'EOF'
date.timezone = Europe/Moscow
ffi.enable = true
EOF

cat > "/etc/php/$LEGACY_PHPVER/fpm/conf.d/30-king-size33.ini" <<'EOF'
memory_limit = 128M
upload_max_filesize = 25M
post_max_size = 25M
expose_php = Off

opcache.memory_consumption = 32
opcache.validate_timestamps = 0

date.timezone = Europe/Moscow
mysqlnd.collect_statistics = Off
EOF

cat > "/etc/php/$LEGACY_PHPVER/cli/conf.d/30-king-size33.ini" <<'EOF'
date.timezone = Europe/Moscow
EOF

# The projects use the unversioned socket. Recreate it after every start of the
# default FPM service; /run is volatile and two FPM versions start in parallel.
install -d -m 755 "/etc/systemd/system/php$PHPVER-fpm.service.d"
cat > "/etc/systemd/system/php$PHPVER-fpm.service.d/default-socket.conf" <<EOF
[Service]
ExecStartPost=/usr/bin/ln -sfn /run/php/php$PHPVER-fpm.sock /run/php/php-fpm.sock
EOF
systemctl daemon-reload
systemctl enable "php$PHPVER-fpm" "php$LEGACY_PHPVER-fpm"

# Restart the versions separately so the default service owns the final link.
systemctl restart "php$LEGACY_PHPVER-fpm"
systemctl restart "php$PHPVER-fpm"

# Keep the unversioned socket used by the modern projects on the default PHP.
if [ "$(readlink -f /run/php/php-fpm.sock 2>/dev/null || true)" != "/run/php/php$PHPVER-fpm.sock" ]; then
    echo "The default PHP-FPM socket does not point to PHP $PHPVER." >&2
    exit 1
fi

install_composer
corepack enable
corepack prepare yarn@1.22.22 --activate
install_acme

nginx -t
apt-get autoremove -y
apt-get clean

cat <<EOF

Initial server setup is complete.

Modern PHP: $PHPVER via /run/php/php-fpm.sock
King-size PHP: $LEGACY_PHPVER via /run/php/php$LEGACY_PHPVER-fpm.sock
MariaDB credentials: /root/.my.cnf

Projects, databases, certificates, nginx sites and application secrets
still need to be restored.
EOF

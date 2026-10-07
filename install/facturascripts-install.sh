#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: Habier
# License: MIT | https://github.com/Habier/facturascripts-community-script/raw/main/LICENSE
# Source: https://facturascripts.com/

# shellcheck disable=SC1091
source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
STRICT_UNSET=1 catch_errors
setting_up_container
network_check
update_os

PHP_VERSION="8.4" PHP_APACHE="YES" setup_php

msg_info "Verifying PHP requirements"
php_version="$(php -r 'echo PHP_VERSION;' 2>/dev/null)"
if ! dpkg --compare-versions "$php_version" ge "8.1"; then
  msg_error "FacturaScripts requires PHP 8.1 or newer; found ${php_version:-unknown}"
  exit 1
fi
required_php_modules=(bcmath curl fileinfo gd mbstring openssl simplexml zip)
loaded_php_modules="$(php -m | tr '[:upper:]' '[:lower:]')"
for module in "${required_php_modules[@]}"; do
  if ! grep -qx "$module" <<<"$loaded_php_modules"; then
    msg_error "Required PHP module is not loaded: $module"
    exit 1
  fi
done
msg_ok "Verified PHP ${php_version} and required modules"

setup_mariadb
mariadb_version="$(mariadb --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)"
if [[ -z "$mariadb_version" ]] || ! dpkg --compare-versions "$mariadb_version" ge "11.2"; then
  msg_error "FacturaScripts requires MariaDB 11.2 or newer; found ${mariadb_version:-unknown}"
  exit 1
fi
msg_ok "Verified MariaDB ${mariadb_version}"
MARIADB_DB_NAME="facturascripts" MARIADB_DB_USER="facturascripts" setup_mariadb_db

fetch_and_deploy_from_url "https://facturascripts.com/DownloadBuild/1/stable" "/opt/facturascripts"

msg_info "Verifying FacturaScripts files"
[[ -f /opt/facturascripts/index.php ]] || {
  msg_error "Downloaded archive is missing expected file: index.php"
  exit 1
}
if [[ ! -f /opt/facturascripts/htaccess-sample && ! -f /opt/facturascripts/.htaccess ]]; then
  msg_error "Downloaded archive contains neither htaccess-sample nor .htaccess"
  exit 1
fi
msg_ok "Verified FacturaScripts files"

msg_info "Configuring FacturaScripts"
if [[ -f /opt/facturascripts/.htaccess ]]; then
  msg_warn "Keeping existing /opt/facturascripts/.htaccess"
else
  mv /opt/facturascripts/htaccess-sample /opt/facturascripts/.htaccess
fi
[[ -s /opt/facturascripts/.htaccess ]] || {
  msg_error "FacturaScripts .htaccess is missing or empty"
  exit 1
}
chown -R root:www-data /opt/facturascripts
find /opt/facturascripts -type d -exec chmod 750 {} +
find /opt/facturascripts -type f -exec chmod 640 {} +
# TEMPORARY first-run access: the web assistant must create config.php in the
# application root. Group write on this directory also lets Apache replace or
# remove root-owned files, so the user must run the hardening command printed
# at completion immediately after finishing the web assistant.
chown root:www-data /opt/facturascripts
chmod 770 /opt/facturascripts
for path in Plugins MyFiles Dinamic; do
  if [[ -d "/opt/facturascripts/${path}" ]]; then
    chown -R www-data:www-data "/opt/facturascripts/${path}"
    find "/opt/facturascripts/${path}" -type d -exec chmod 770 {} +
    find "/opt/facturascripts/${path}" -type f -exec chmod 660 {} +
  fi
done
msg_ok "Configured FacturaScripts"

cat <<'EOF' >/usr/local/sbin/facturascripts-harden-permissions
#!/usr/bin/env bash
set -Eeuo pipefail

app_root=/opt/facturascripts
[[ -f "${app_root}/config.php" ]] || {
  echo "Refusing to harden: ${app_root}/config.php does not exist. Complete the web setup first." >&2
  exit 1
}

chown -R root:www-data "$app_root"
find "$app_root" -type d -exec chmod 750 {} +
find "$app_root" -type f -exec chmod 640 {} +

for path in Plugins MyFiles Dinamic; do
  if [[ -d "${app_root}/${path}" ]]; then
    chown -R www-data:www-data "${app_root}/${path}"
    find "${app_root}/${path}" -type d -exec chmod 770 {} +
    find "${app_root}/${path}" -type f -exec chmod 660 {} +
  fi
done

root_mode="$(stat -c '%a' "$app_root")"
root_owner="$(stat -c '%U:%G' "$app_root")"
[[ "$root_mode" == "750" && "$root_owner" == "root:www-data" ]] || {
  echo "Permission verification failed for ${app_root}: ${root_owner} ${root_mode}" >&2
  exit 1
}

echo "FacturaScripts permissions hardened. Apache can write only to existing Plugins, MyFiles, and Dinamic directories."
EOF
chmod 750 /usr/local/sbin/facturascripts-harden-permissions

msg_info "Configuring Apache"
$STD a2enmod rewrite
cat <<'EOF' >/etc/apache2/sites-available/facturascripts.conf
<VirtualHost *:80>
    ServerName _
    DocumentRoot /opt/facturascripts

    <Directory /opt/facturascripts>
        Options -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/facturascripts-error.log
    CustomLog ${APACHE_LOG_DIR}/facturascripts-access.log combined
</VirtualHost>
EOF
$STD a2ensite facturascripts.conf
$STD a2dissite 000-default.conf
$STD apache2ctl configtest
$STD systemctl enable --now apache2
$STD systemctl reload apache2
if ! systemctl is-active --quiet apache2; then
  msg_error "Apache is not active after configuration"
  exit 1
fi
if ! http_status="$(curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 3 --max-time 10 --retry 4 --retry-connrefused --retry-delay 1 --retry-max-time 20 http://127.0.0.1/)"; then
  msg_error "FacturaScripts HTTP check could not connect to http://127.0.0.1/"
  exit 1
fi
if [[ ! "$http_status" =~ ^(2|3)[0-9][0-9]$ ]]; then
  msg_error "FacturaScripts HTTP check failed with status ${http_status}"
  exit 1
fi
msg_ok "Configured Apache"

echo -e "${INFO}${YW}Complete the FacturaScripts web installer with:${CL}"
echo -e "${TAB}Database host: localhost"
echo -e "${TAB}Database name: ${MARIADB_DB_NAME}"
echo -e "${TAB}Database user: ${MARIADB_DB_USER}"
echo -e "${TAB}Database password: ${MARIADB_DB_PASS}"
echo -e "${INFO}${RD}SECURITY ACTION REQUIRED after the web wizard:${CL}"
echo -e "${TAB}Run as root: /usr/local/sbin/facturascripts-harden-permissions"
echo -e "${TAB}Until then, Apache can replace files in /opt/facturascripts."

motd_ssh
customize
cleanup_lxc

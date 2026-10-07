#!/usr/bin/env bash
_CS_DEFAULT_URL="https://raw.githubusercontent.com/Habier/facturascripts-community-script/main"
_cs_boot="${COMMUNITY_SCRIPTS_CORE_DIR:-$(dirname "${BASH_SOURCE[0]}")/../../core}/core/build.func"
# shellcheck disable=SC1090
source "$_cs_boot" 2>/dev/null || source <(curl -fsSL "${COMMUNITY_SCRIPTS_CORE_URL:-https://raw.githubusercontent.com/community-scripts/core/main}/core/build.func")

# Copyright (c) 2021-2026 community-scripts ORG
# Author: Habier
# License: MIT | https://github.com/Habier/facturascripts-community-script/raw/main/LICENSE
# Source: https://facturascripts.com/

APP="FacturaScripts"
var_tags="${var_tags:-business;erp;finance}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-20}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
#var_arm64="${var_arm64:-no}" # unset = ask the user; set yes/no only when verified
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  if [[ ! -f /opt/facturascripts/index.php ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  msg_error "FacturaScripts must be updated through its built-in updater in the web interface."
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW}Complete the setup wizard using the database credentials shown above.${CL}"
echo -e "${WARN}${RD}After the wizard, hardening is still REQUIRED. Run inside the container as root:${CL}"
echo -e "${TAB}/usr/local/sbin/facturascripts-harden-permissions"
echo -e "${INFO}${YW}Access it using the following URL:${CL}"
echo -e "${GATEWAY}${BGN}http://${IP}${CL}"

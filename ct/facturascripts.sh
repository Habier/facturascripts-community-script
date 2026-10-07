#!/usr/bin/env bash
_CS_DEFAULT_URL="https://raw.githubusercontent.com/Habier/facturascripts-community-script/main"
_cs_boot="${COMMUNITY_SCRIPTS_CORE_DIR:-$(dirname "${BASH_SOURCE[0]}")/../../core}/core/build.func"
if [[ -s "$_cs_boot" ]]; then
  # shellcheck disable=SC1090
  source "$_cs_boot" || {
    echo "Error: failed to load the local Community Scripts core: ${_cs_boot}" >&2
    exit 1
  }
else
  _cs_boot_url="${COMMUNITY_SCRIPTS_CORE_URL:-https://raw.githubusercontent.com/community-scripts/core/main}/core/build.func"
  if ! _cs_boot_content="$(curl -fsSL "$_cs_boot_url")" || [[ -z "$_cs_boot_content" ]]; then
    echo "Error: failed to download a non-empty Community Scripts core from ${_cs_boot_url}" >&2
    exit 1
  fi
  # shellcheck disable=SC1090
  source /dev/stdin <<<"$_cs_boot_content" || {
    echo "Error: failed to load the downloaded Community Scripts core from ${_cs_boot_url}" >&2
    exit 1
  }
fi

_cs_required_functions=(header_info variables color catch_errors check_container_storage check_container_resources msg_error start build_container description msg_ok)
for _cs_function in "${_cs_required_functions[@]}"; do
  if ! declare -F "$_cs_function" >/dev/null; then
    echo "Error: Community Scripts core is missing required function: ${_cs_function}" >&2
    exit 1
  fi
done
unset _cs_boot_content _cs_boot_url _cs_function _cs_required_functions

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
    exit 1
  fi

  msg_error "FacturaScripts must be updated through its built-in updater in the web interface."
  exit 1
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW}Complete the setup wizard using the database credentials shown above.${CL}"
echo -e "${INFO}${RD}After the wizard, hardening is still REQUIRED. Run inside the container as root:${CL}"
echo -e "${TAB}/usr/local/sbin/facturascripts-harden-permissions"
echo -e "${INFO}${YW}Access it using the following URL:${CL}"
echo -e "${GATEWAY}${BGN}http://${IP}${CL}"

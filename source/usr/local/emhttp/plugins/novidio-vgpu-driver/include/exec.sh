#!/bin/bash
# exec.sh - helper functions for the novidio-vgpu-driver plugin page

PLUGIN="novidio-vgpu-driver"
PLGCFG="/boot/config/plugins/${PLUGIN}"
SETTINGS="${PLGCFG}/settings.cfg"
EMHTTP="/usr/local/emhttp/plugins/${PLUGIN}"
RC="${EMHTTP}/scripts/rc.vgpu"
KERNEL_V="$(uname -r)"
VERSIONS_CACHE="/tmp/novidio_vgpu_driver"
CRON_LINE="${EMHTTP}/include/update-check.sh"

# refresh the cache of driver versions available for this kernel (throttled to 5 min)
update() {
  if [ -f "${VERSIONS_CACHE}" ]; then
    local age=$(( $(date +%s) - $(stat -c %Y "${VERSIONS_CACHE}") ))
    [ ${age} -lt 300 ] && return 0
  fi
  # asset names: nvidia-<driver version>-<kernel>-Unraid-1.txz -> field 2 is the version
  wget -T 15 -qO- "https://api.github.com/repos/novidio/unraid-novidio-vgpu-driver/releases/tags/${KERNEL_V}" 2>/dev/null \
    | jq -r '.assets[].name' 2>/dev/null \
    | grep '^nvidia-' | grep -E -v '\.md5$' \
    | cut -d '-' -f2 | sort -V | uniq | tail -10 > "${VERSIONS_CACHE}"
  if [ ! -s "${VERSIONS_CACHE}" ]; then
    modinfo -F version nvidia 2>/dev/null | head -1 > "${VERSIONS_CACHE}"
  fi
}

get_latest_version() {
  echo -n "$(tail -1 "${VERSIONS_CACHE}" 2>/dev/null)"
}

get_available_versions() {
  cat "${VERSIONS_CACHE}" 2>/dev/null
}

get_installed_version() {
  echo -n "$(modinfo -F version nvidia 2>/dev/null | head -1)"
}

get_selected_version() {
  echo -n "$(grep -m1 '^driver_version=' "${SETTINGS}" 2>/dev/null | cut -d '=' -f2)"
}

# download (if needed) and live-install a driver version; runs inside an openBox window
update_driver() {
  local want="${1:-latest}"
  sed -i "/^driver_version=/c\driver_version=${want}" "${SETTINGS}" 2>/dev/null
  if "${EMHTTP}/include/download.sh" "${want}"; then
    echo
    "${RC}" update
  else
    exit 1
  fi
}

restart_services() {
  echo "-----------------------Restarting vGPU services...------------------------------"
  "${RC}" restart
  echo
  "${RC}" status
  echo
  echo "----------------------------------DONE------------------------------------------"
}

apply_devices() {
  "${RC}" apply
}

change_update_check() {
  sed -i "/^update_check=/c\update_check=${1}" "${SETTINGS}"
  if [ "${1}" = "true" ]; then
    if ! crontab -l 2>/dev/null | grep -q "${CRON_LINE}"; then
      (crontab -l 2>/dev/null; echo "$((RANDOM % 59)) $(shuf -i 8-9 -n 1) * * * ${CRON_LINE} &>/dev/null 2>&1") | crontab -
    fi
  else
    crontab -l 2>/dev/null | grep -v "${CRON_LINE}" | crontab -
  fi
}

"$@"

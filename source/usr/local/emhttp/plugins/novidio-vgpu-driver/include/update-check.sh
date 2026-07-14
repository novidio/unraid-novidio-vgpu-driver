#!/bin/bash
# update-check.sh - daily cron job: download a newer driver build if one exists
# and notify the user. Never touches the running driver.

PLUGIN="novidio-vgpu-driver"
PLGCFG="/boot/config/plugins/${PLUGIN}"
SETTINGS="${PLGCFG}/settings.cfg"
EMHTTP="/usr/local/emhttp/plugins/${PLUGIN}"
KERNEL_V="$(uname -r)"

notify() {
  /usr/local/emhttp/plugins/dynamix/scripts/notify -e "Nvidia vGPU Driver" -d "$1" -i "${2:-normal}" -l "/Settings/${PLUGIN}"
}

# only auto-check when the user follows the latest version
SET_DRV_V="$(grep -m1 '^driver_version=' "${SETTINGS}" 2>/dev/null | cut -d '=' -f2)"
[ "${SET_DRV_V}" = "latest" ] || exit 0

INSTALLED_V="$(modinfo -F version nvidia 2>/dev/null | head -1)"
LATEST_V="$(wget -T 15 -qO- "https://api.github.com/repos/novidio/unraid-novidio-vgpu-driver/releases/tags/${KERNEL_V}" 2>/dev/null \
  | jq -r '.assets[].name' 2>/dev/null \
  | grep '^nvidia-' | grep -E -v '\.md5$' \
  | cut -d '-' -f2 | sort -V | uniq | tail -1)"

if [ -z "${LATEST_V}" ]; then
  logger -t "${PLUGIN}" "Automatic update check failed, can't get latest version number!"
  exit 1
fi

[ "${LATEST_V}" = "${INSTALLED_V}" ] && exit 0

if "${EMHTTP}/include/download.sh" latest >/dev/null 2>&1; then
  notify "New Nvidia vGPU driver v${LATEST_V} downloaded! Open Settings -> Novidio vGPU and click 'Update Now' to install it without a reboot."
else
  notify "New Nvidia vGPU driver v${LATEST_V} found but the download failed. Please try from the plugin page." "alert"
fi

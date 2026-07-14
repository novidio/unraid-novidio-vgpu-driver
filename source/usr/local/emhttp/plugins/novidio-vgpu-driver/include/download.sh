#!/bin/bash
# download.sh [version] - make sure the requested driver package for the running
# kernel is present on the flash drive. "latest" (default) picks the newest build.
# Called from the .plg on boot/install and from the plugin page before an update.

PLUGIN="novidio-vgpu-driver"
PLGCFG="/boot/config/plugins/${PLUGIN}"
SETTINGS="${PLGCFG}/settings.cfg"
KERNEL_V="$(uname -r)"
PKGDIR="${PLGCFG}/packages/${KERNEL_V%%-*}"
DL_URL="https://github.com/novidio/unraid-novidio-vgpu-driver/releases/download/${KERNEL_V}"
API_URL="https://api.github.com/repos/novidio/unraid-novidio-vgpu-driver/releases/tags/${KERNEL_V}"

WANT="${1:-$(grep -m1 '^driver_version=' "${SETTINGS}" 2>/dev/null | cut -d '=' -f2)}"
[ -n "${WANT}" ] || WANT="latest"

mkdir -p "${PKGDIR}"
LOCAL_PKG="$(ls "${PKGDIR}"/nvidia-*.txz 2>/dev/null | sort -V | tail -1)"

md5_ok() {
  [ -f "${1}" ] && [ -f "${1}.md5" ] || return 1
  [ "$(md5sum "${1}" | awk '{print $1}')" = "$(awk '{print $1}' "${1}.md5")" ]
}

# list of available package assets for this kernel (may be empty when offline)
AVAIL="$(wget -T 15 -qO- "${API_URL}" | jq -r '.assets[].name' 2>/dev/null | grep '^nvidia-' | grep -E -v '\.md5$' | sort -V)"

if [ -z "${AVAIL}" ]; then
  if [ -n "${LOCAL_PKG}" ]; then
    echo "---Can't reach GitHub, using local driver package $(basename "${LOCAL_PKG}")---"
    exit 0
  fi
  echo
  echo "-----ERROR - ERROR - ERROR - ERROR - ERROR - ERROR - ERROR - ERROR - ERROR------"
  echo "----No driver package found for kernel ${KERNEL_V} and no local copy exists----"
  echo "---Check your internet connection, or wait for a build for this kernel to be---"
  echo "---------------published, then reinstall/update the plugin.--------------------"
  exit 1
fi

# packages are named nvidia-<driver version>-<kernel>-Unraid-1.txz
if [ "${WANT}" = "latest" ]; then
  PKG="$(echo "${AVAIL}" | tail -1)"
else
  PKG="$(echo "${AVAIL}" | grep -- "-${WANT}-" | sort -V | tail -1)"
  if [ -z "${PKG}" ]; then
    echo "---Requested driver v${WANT} not found for this kernel, falling back to latest---"
    PKG="$(echo "${AVAIL}" | tail -1)"
    sed -i '/^driver_version=/c\driver_version=latest' "${SETTINGS}" 2>/dev/null
  fi
fi
PKG_V="$(echo "${PKG}" | cut -d '-' -f2)"

if md5_ok "${PKGDIR}/${PKG}"; then
  echo "-------Nvidia vGPU driver package v${PKG_V} already downloaded, checksum OK-------"
else
  echo
  echo "+==============================================================================="
  echo "| Downloading Nvidia vGPU driver package v${PKG_V} for kernel ${KERNEL_V}"
  echo "| Please don't close this window until it is finished!"
  echo "+==============================================================================="
  echo
  rm -f "${PKGDIR}/${PKG}" "${PKGDIR}/${PKG}.md5"
  if wget -q --show-progress --progress=bar:force:noscroll -O "${PKGDIR}/${PKG}" "${DL_URL}/${PKG}" &&
     wget -q -O "${PKGDIR}/${PKG}.md5" "${DL_URL}/${PKG}.md5" &&
     md5_ok "${PKGDIR}/${PKG}"; then
    echo
    echo "----------Successfully downloaded Nvidia vGPU driver package v${PKG_V}----------"
  else
    rm -f "${PKGDIR}/${PKG}" "${PKGDIR}/${PKG}.md5"
    echo
    echo "-----ERROR - ERROR - ERROR - ERROR - ERROR - ERROR - ERROR - ERROR - ERROR------"
    echo "-------Download or checksum of driver package v${PKG_V} failed!----------------"
    if [ -n "${LOCAL_PKG}" ]; then
      echo "---------Keeping existing local package $(basename "${LOCAL_PKG}")---------"
      exit 0
    fi
    exit 1
  fi
fi

# remove packages for other kernels and older builds for this kernel
for d in "${PLGCFG}/packages/"*/; do
  [ "${d}" = "${PKGDIR}/" ] || rm -rf "${d}"
done
for f in "${PKGDIR}"/*; do
  case "$(basename "${f}")" in
    "${PKG}"|"${PKG}.md5") ;;
    *) rm -f "${f}" ;;
  esac
done
exit 0

# Unraid Nvidia vGPU Driver plugin

# NO LONGER MERGED DRIVER!!!!

As of 6.12.54 we are no longer using the merged driver. This means the driver will not work on docker containers in Unraid. The driver will only support vGPU usage in a virtual machine.

- Latest version currently supported: Check releases tab
- Unraid driver for vGPU. Split your GPU amongst VMs.
- This is the repository for the Unraid vGPU Driver plugin.

## How it works

Install the plugin, then go to **Settings → Novidio vGPU**. Everything is managed from
that page — **no user-scripts script is needed anymore**:

1. The plugin downloads and installs the driver build matching your Unraid kernel
   (published on the releases tab, tagged by kernel version).
2. At every boot the plugin loads the modules in the right order
   (`nvidia` → `mdev` → `nvidia-vgpu-vfio`), starts `nvidia-vgpud` / `nvidia-vgpu-mgr`
   with vgpu_unlock, waits for the vGPU types to appear and recreates your configured
   vGPU devices.
3. On the plugin page you add a vGPU by picking your GPU, a profile (read live from
   the driver) and a UUID (generated for you). The page shows the `<hostdev>` XML
   snippet to paste into your VM template — uuid is the only thing that differs
   per device:

```xml
    <hostdev mode='subsystem' type='mdev' managed='no' model='vfio-pci' display='off' ramfb='off'>
      <source>
        <address uuid='2b6976dd-8620-49de-8d8d-ae9ba47a50db'/>
      </source>
    </hostdev>
```

## Driver updates without a reboot

When a new driver build is available the plugin page shows an **Update Now** button.
The update stops the vGPU devices and daemons, unloads the old module, installs the
new package and brings everything back up — no reboot needed. If a VM is holding a
vGPU the module can't be unloaded; the plugin then keeps the old driver running and
the new one installs on the next reboot instead.

## Settings stored on the flash drive

| Path | Purpose |
|---|---|
| `/boot/config/plugins/novidio-vgpu-driver/settings.cfg` | plugin settings (`unlock`, `update_check`, …) |
| `/boot/config/plugins/novidio-vgpu-driver/vgpu-devices.cfg` | your vGPU devices (`UUID\|PCI\|TYPE`, managed by the page) |
| `/boot/config/nvidia-vgpu/profile_override.toml` | vgpu_unlock profile overrides (editable on the page) |
| `/boot/config/nvidia-vgpu/vgpuConfig.xml` | **optional** vgpuConfig.xml override |

### vgpuConfig.xml override (older GPUs, e.g. Pascal / Tesla P4)

`nvidia-vgpud` only accepts GPUs listed in `/usr/share/nvidia/vgpu/vgpuConfig.xml`.
The 550 (vGPU 17.x) driver dropped Pascal cards from that file, so the daemon logs
`GPU not supported by vGPU` and no mdev types appear. Fix: extract `vgpuConfig.xml`
from a 16.x (535) vgpu-kvm host driver and place it at
`/boot/config/nvidia-vgpu/vgpuConfig.xml`. The plugin applies it before starting the
daemons at every boot and after **Restart vGPU Services**.

### vGPU unlock

The *vGPU unlock* setting on the plugin page is the single source of truth for
`/etc/vgpu_unlock/config.toml`. Leave it **disabled** for natively supported cards
(Tesla/Quadro — you get the native profiles, e.g. `P4-1Q`); enable it to spoof
consumer GPUs. Changing it requires **Restart vGPU Services**. Note that the
reported device ID changes with this setting (a P4 spoofed as P40 exposes different
profile IDs), so pick your profile after setting it.

### Credits
- Thanks to stl88083365 for the unraid plugin foundation
- Thanks to the discord user @mbuchel for the experimental patches
- Thanks to the discord user @LIL'pingu for the extended 43 crash fix
- Special thanks to @DualCoder without his work (vGPU_Unlock) we would not be here
- and thanks to the discord user @snowman for creating this patcher
- thanks to the discord user @midi creating this shell scripts

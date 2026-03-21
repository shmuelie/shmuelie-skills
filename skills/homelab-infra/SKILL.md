---
name: homelab-infra
description: Proxmox GPU passthrough, LXC containers, Home Assistant dashboards, Jellyfin plugins, ComfyUI nodes
---

When working on projects related to homelab infrastructure patterns, apply this domain knowledge.

# Homelab Infrastructure — Domain Knowledge

## Proxmox VE (PVE)

### NVIDIA GPU Passthrough to LXC Containers
**Host setup:**
1. Blacklist nouveau driver: `echo "blacklist nouveau" > /etc/modprobe.d/blacklist-nouveau.conf`
2. Install build deps: `apt install dkms pve-headers-$(uname -r)`
3. Download and install latest NVIDIA driver from download.nvidia.com via DKMS
4. Load kernel modules: `nvidia`, `nvidia_uvm` (persist in `/etc/modules-load.d/`)

**Container configuration (`/etc/pve/lxc/<CTID>.conf`):**
```
lxc.cgroup2.devices.allow: c 195:* rwm    # nvidia devices
lxc.cgroup2.devices.allow: c 509:* rwm    # nvidia-uvm
lxc.mount.entry: /dev/nvidia0 dev/nvidia0 none bind,optional,create=file
lxc.mount.entry: /dev/nvidiactl dev/nvidiactl none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-uvm dev/nvidia-uvm none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-uvm-tools dev/nvidia-uvm-tools none bind,optional,create=file
```
- Read device major:minor numbers from host device nodes dynamically.
- Make config idempotent — remove old GPU entries before adding new ones.

**Container-side driver install:**
- Use `pct push` to send the install script into the container.
- Use `pct exec <CTID>` to execute it inside.
- Install with `--no-kernel-module` flag (userspace libraries only).
- Driver version MUST match the host's kernel module version exactly.
- Detect host version via `nvidia-smi --query-gpu=driver_version --format=csv,noheader`.

### Proxmox Boot Management
- `update-initramfs -u -k all` — update initramfs for ALL installed kernels.
- `proxmox-boot-tool refresh` — REQUIRED on Proxmox to sync initramfs to EFI System Partition(s).
  A plain `update-initramfs -u` does NOT refresh the actual boot ESP partitions.
- `-q` (quiet) flag may not be valid for all versions of `update-initramfs`.

### LXC Container Management
- `pct start/stop/restart <CTID>` — container lifecycle.
- `pct push <CTID> <local-path> <container-path>` — copy files into container.
- `pct exec <CTID> -- <command>` — run commands inside container.

## Home Assistant

### Proxmox Integration Entities
Entity naming pattern for Proxmox VE integration:
- `binary_sensor.pve_<node>_status` — running/stopped
- `sensor.pve_<node>_cpu_usage` — CPU percentage
- `sensor.pve_<node>_memory_usage` — memory in GiB
- `sensor.pve_<node>_disk_usage` — disk in GiB
- `sensor.pve_<node>_max_cpu` / `max_memory_usage` / `max_disk_usage`
- `button.pve_<node>_start` / `stop` / `restart`
- Same pattern for VMs/LXCs: `sensor.pve_<vm_name>_cpu_usage`, etc.

### Dashboard YAML Structure
- Dashboards can be YAML-based or UI-managed (`.storage/lovelace*`).
- For YAML: add `lovelace:` section to `configuration.yaml`.
- Use gauge cards for CPU/memory/disk metrics.
- Use entity cards with conditional visibility for VM/LXC status.
- Group by: Node overview → VMs → LXC Containers.

### Configuration Patterns
- `configuration.yaml` splits config via `!include` directives.
- Automation IDs follow specific format conventions.
- REST sensor naming patterns for external integrations.
- PyScript: `@pyscript_executor` for I/O, `@service` for HA services.
- Secrets referenced via `!secret` — never committed.

## Jellyfin Plugin Development

### Provider Pattern
- Each content type needs: local metadata provider + remote metadata provider + image provider.
- `Video` base type uses `ItemLookupInfo` directly (no custom lookup info class).
- Implement `IHasLookupInfo<T>` for metadata lookup.
- `IRemoteMetadataProvider<Video, ItemLookupInfo>` for remote providers.
- `ILocalMetadataProvider<Video>` for local file-based metadata.

### Plugin Architecture
- Entry point → DI registration → controller → service → web UI.
- Data flow: `ILibraryManager` → `IMediaSourceManager` → post-filtering.
- NuGet `ExcludeAssets="runtime"` on host framework references (don't bundle host assemblies).
- `build.yaml` manifest must be kept in sync with plugin metadata.
- Dev containers recommended for Jellyfin plugin development.

## ComfyUI Custom Nodes

### Node Development
- Files follow `nodes_*.py` naming convention — auto-discovered on startup.
- Node class needs: `INPUT_TYPES`, `RETURN_TYPES`, `FUNCTION`, `CATEGORY` class attributes.
- Category format: `"api node/image/Vendor Name"` for API-based nodes.
- Use `sync_op_raw` with absolute URLs to bypass Comfy.org auth headers.
- SD WebUI API response: `{"images": ["base64..."], "parameters": {...}, "info": "..."}`.

### Blueprint Format
- Top level: single "container" node representing a subgraph.
- `definitions.subgraphs[]`: inner nodes, links, inputs, outputs.
- Follow existing patterns (e.g., Gemini Image Captioning) for single-node wrappers.

### Remote API Integration (Qualcomm AIC100 / SD WebUI)
- Port 7860 = Gradio / Stable Diffusion WebUI API.
- Key endpoints: `/sdapi/v1/txt2img`, `/sdapi/v1/img2img`, `/sdapi/v1/sd-models`,
  `/sdapi/v1/samplers`, `/sdapi/v1/loras`, `/sdapi/v1/progress`.
- Images returned as base64-encoded strings in response arrays.
- Use RemoteOptions pattern for dynamic dropdown options from API.

# shmuelie-systems

Systems development: embedded Linux and C++, self-hosted infrastructure, media
and automation services, and Qualcomm Cloud AI 100 accelerators.

**Version:** 0.1.0

## Install

```text
copilot plugin marketplace add shmuelie/shmuelie-skills
copilot plugin install shmuelie-systems@shmuelie-skills
```

Update or remove:

```text
copilot plugin update shmuelie-systems
copilot plugin uninstall shmuelie-systems
```

## Skills

### embedded-cpp

Embedded C++ on Linux: a Buildroot external tree for cross-compilation, CMake
presets, binary size optimization (`-fno-rtti`, `-fno-unwind-tables`, UPX,
libstdc++ size flags), C++-standard-vs-libc decoupling, long-running-freeze leak
diagnosis with a host valgrind harness, `FetchContent`, Catch2 testing, C++20
conventions, MQTT Home Assistant auto-discovery, and old kernel / uClibc
compatibility.

### homelab-infra

Self-hosted infrastructure: Proxmox NVIDIA GPU passthrough to LXC containers
(driver matching, `lxc.cgroup2`, `pct push/exec`), Home Assistant dashboard YAML
and Proxmox entity naming, Jellyfin plugin provider architecture and server
administration, and ComfyUI custom node development.

### qualcomm-aic

Qualcomm Cloud AI 100 NPU: SDK installation and upgrades, the GLIBCXX RUNPATH
conflict fix, the ONNX→QPC compilation pipeline, Stable Diffusion model type
detection (safetensors keys vs file size), LoRA auto-activation control, job ETA,
and an SD WebUI compatible API.

## Example requests

```text
Create a Buildroot external tree for this embedded target.
Reduce this C++ binary without changing its required features.
Pass an NVIDIA GPU through to a Proxmox LXC container.
Build a Jellyfin metadata provider plugin.
Compile this ONNX model for Qualcomm Cloud AI 100.
Diagnose this GLIBCXX conflict in the accelerator SDK.
```

## Environment notes

These workflows often operate on remote Linux hosts or appliances. Confirm the
target architecture, libc, kernel, driver, and accelerator SDK versions before
changing build flags or system configuration.

## Changelog

Each skill has its own `CHANGELOG.md`; marketplace-wide history is in the
[repository changelog](../../../CHANGELOG.md).

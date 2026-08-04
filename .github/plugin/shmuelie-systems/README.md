# shmuelie-systems

Systems-development skills for embedded Linux and C++, self-hosted
infrastructure, media and automation services, and Qualcomm Cloud AI 100
accelerators.

**Version:** 0.1.1

**Catalog:** [`shmuelie-skills`](../../../README.md)

**Changelog:** [`CHANGELOG.md`](../../../CHANGELOG.md)

## Install

```text
copilot plugin marketplace add shmuelie/shmuelie-skills
copilot plugin install shmuelie-systems@shmuelie-skills
```

```text
copilot plugin update shmuelie-systems
copilot plugin uninstall shmuelie-systems
```

## Skills

| Skill | Use it for |
|---|---|
| [`embedded-cpp`](skills/embedded-cpp/SKILL.md) | Buildroot external trees, cross-compilation, compatibility, binary size, tests, deployment, and MQTT |
| [`homelab-infra`](skills/homelab-infra/SKILL.md) | Proxmox LXC and GPU passthrough, Home Assistant, Jellyfin, and ComfyUI integrations |
| [`qualcomm-aic`](skills/qualcomm-aic/SKILL.md) | Install and troubleshoot the AIC100 SDK, compile ONNX models to QPC, and expose inference APIs |

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

These workflows often operate on remote Linux hosts or appliances. Confirm
target architecture, libc, kernel, driver, and accelerator SDK versions before
changing build flags or system configuration.

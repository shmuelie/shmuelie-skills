---
name: embedded-cpp
description: Buildroot cross-compilation, binary size optimization, FetchContent, Catch2, C++20 conventions, and MQTT
---

When working on projects related to embedded c++ / cmake patterns, apply this domain knowledge.

# Embedded C++ / CMake Cross-Compilation — Domain Knowledge

## Buildroot Cross-Compilation Toolchain
- Use Buildroot as an external tree for generating MIPS (or other arch) cross-compilation toolchains.
- Structure:
  ```
  br2/
  ├── CMakeLists.txt         # Buildroot integration, sets CMAKE_TOOLCHAIN_FILE
  ├── Config.in
  ├── board/<vendor>/<device>/
  │   └── uclibc.config      # uClibc configuration for target
  ├── configs/
  │   └── <device>_defconfig # Buildroot default config
  ├── external.desc
  └── external.mk
  ```
- CMake integration: if cross-compiling, run Buildroot first, then set `CMAKE_TOOLCHAIN_FILE`
  to Buildroot's generated toolchain file.
- Use CMake presets for local vs cross-compile builds:
  ```json
  { "name": "mips-release", "cacheVariables": { "MFI_CROSS_COMPILE": "ON", "CMAKE_BUILD_TYPE": "MinSizeRel" } }
  { "name": "local-debug",  "cacheVariables": { "CMAKE_BUILD_TYPE": "Debug" } }
  ```

## Binary Size Optimization (Embedded Targets)
### Compile/Link Flags
- `-fno-unwind-tables` — removes unwind info (saves ~5-10%)
- `-fmerge-all-constants` — deduplicates constant data
- `-fvisibility=hidden` — hides all symbols by default (smaller PLT/GOT)
- `-Wl,--exclude-libs,ALL` — excludes all library symbols from export
- `-fno-rtti` — strips typeinfo/vtable name strings (~11% savings)
  - Requires replacing `dynamic_pointer_cast` with `static_pointer_cast`
    where the downcast type is guaranteed (e.g., same type registered in init()).
- `-fno-exceptions` — only if exceptions aren't used

### UPX Compression (~62% on-disk reduction)
- CMake integration pattern:
  ```cmake
  option(MFI_UPX "Compress executables with UPX" OFF)
  # Smart default: ON for Release/MinSizeRel, OFF for Debug
  if(NOT DEFINED MFI_UPX)
    if(CMAKE_BUILD_TYPE MATCHES "Release|MinSizeRel")
      set(MFI_UPX ON)
    endif()
  endif()

  if(MFI_UPX)
    find_program(UPX_EXECUTABLE upx upx-ucl)
    if(NOT UPX_EXECUTABLE)
      # FATAL if user explicitly requested, WARN if just defaulted
      if(MFI_UPX_WAS_SET_BY_USER)
        message(FATAL_ERROR "UPX requested but not found")
      else()
        message(WARNING "UPX not found, skipping compression")
      endif()
    else()
      add_custom_command(TARGET myexe POST_BUILD
        COMMAND ${UPX_EXECUTABLE} --best -q $<TARGET_FILE:myexe>)
    endif()
  endif()
  ```
- In-memory size doesn't shrink (UPX decompresses at load time).

## CMake Dependency Management
### FetchContent (preferred for header-only/small libs)
```cmake
include(FetchContent)
FetchContent_Declare(CLI11 GIT_REPOSITORY https://github.com/CLIUtils/CLI11.git GIT_TAG v2.3.2)
FetchContent_MakeAvailable(CLI11)
target_link_libraries(myapp PRIVATE CLI11::CLI11)
```
- Pin to specific commits or tags for reproducibility.
- Good for: CLI11, Catch2, nlohmann_json, mongoose.
- Use `find_package()` + `pkg_check_modules()` for system libraries (mosquitto, spdlog).

### Catch2 Testing
```cmake
FetchContent_Declare(Catch2 GIT_REPOSITORY https://github.com/catchorg/Catch2.git GIT_TAG v3.5.2)
FetchContent_MakeAvailable(Catch2)
include(Catch2/extras/Catch.cmake)

add_executable(tests test_foo.cpp test_bar.cpp)
target_link_libraries(tests PRIVATE Catch2::Catch2WithMain mylib)
catch_discover_tests(tests)
```
- Use `TEST_CASE` with tag-based organization: `[module][feature]`.
- RAII helper classes for test fixture setup/teardown.

## C++20 Embedded Conventions (from mfi-custom-code)
- **Naming**: `snake_case` for everything (classes, methods, namespaces).
- **Members**: underscore prefix (`_name`, `_sensors`).
- **Exes**: kebab-case (`mfi-cli`, `mfi-mqtt-client`).
- **Headers**: `#pragma once` (not `#ifndef` guards).
- **Modern features**: `std::optional`, `std::string_view`, `noexcept`, `final` classes.
- **RAII**: File handles, MQTT connections, all resource management.
- **const correctness**: Heavy use of `const&` parameters, `const` methods.

## Embedded Device Deployment Patterns
- 64KB persistent storage limit on some embedded devices (Ubiquiti mFi).
- Download binaries to `/tmp` on boot (volatile, but no size limit).
- Use `cfgmtd -w -p /etc/` to commit config changes to persistent storage.
- Startup flow: `rc.poststart` → `rc.poststart.d/*` (modular, parallel).
- Deployment script: archive → SCP → stop services → clear bin → commit → restart.
- Symlink-based device config directories (DRY — shared files aren't duplicated).

## Old Kernel / uClibc Compatibility (CRITICAL)
- **`statx` syscall** (Linux 4.11+): uClibc-ng 1.0.50+ defaults `UCLIBC_USE_TIME64=y` on 32-bit MIPS,
  which makes `stat()` use the `statx` syscall internally. Old kernels don't have `statx`,
  so **every `stat()` call fails with ENOSYS** — breaking all file existence checks system-wide.
  Fix: set `# UCLIBC_USE_TIME64 is not set` in the uClibc config to use `stat64` (syscall 4213) instead.
- **`std::filesystem`**: Libraries like CLI11 auto-detect `<filesystem>` at compile time (GCC 14 has it)
  and use `std::filesystem::status()` which calls `statx()`. On old kernels this always returns
  "nonexistent". Fix: define `CLI11_HAS_FILESYSTEM=0` for cross-compiled builds to force plain `stat()`.
- **Relative vs absolute paths**: Embedded init scripts may set `cwd` to `/` or `/tmp`, not where
  binaries/configs live. Always pass absolute paths. If paths resolve from `/`, reads may "work"
  accidentally while writes fail silently.
- **Carriage returns**: Scripts edited on Windows get `\r` at line ends, corrupting paths.
  Check with `cat -A script.sh | grep '^M'`.

## Home Assistant MQTT Auto-Discovery
- Native libmosquitto client (not shelling out to `mosquitto_pub`).
- Publish HA discovery payloads to `homeassistant/<type>/<device_id>/config`.
- Change-only updates (don't flood MQTT with unchanged values).
- Device classes: switch + sensor entities per outlet/port.

### MQTT Topic ID Deduplication
- When connector ID, device ID, and device name are all derived from hostname,
  the full topic path gets triple-duplication: `home/host_host_host/sensor/state`.
- Fix: sanitize connector ID with the same function as device IDs, then skip
  appending `m_id`/`m_clean_name` when they equal the connector ID.
- Initialization order matters: register device with connector BEFORE registering
  child functions/sensors, otherwise `m_full_id` is empty and topics become `home//sensor/state`.

## Multi-Project Versioning (Monorepo)
- Use per-project CHANGELOGs following Keep a Changelog format.
- Tag pattern: `<project>/<vX.Y.Z>` (e.g., `mfi-mqtt-client/v1.1.0`).
- Each project follows SemVer independently.
- Attach binaries to GitHub releases for deployment artifacts.

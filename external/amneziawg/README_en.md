# AmneziaWG Kernel Module Integration

English | [简体中文](README.md)

This directory integrates a pinned release of the [AmneziaWG Linux kernel module](https://github.com/amnezia-vpn/amneziawg-linux-kernel-module) as an in-tree module in the shared Cloud Kernel BBRv3 kernel build and every package format.

> [!NOTE]
> The kernel packages contain only the `amneziawg` kernel module. Compatible `awg` and `awg-quick` userspace tools must be installed separately to create and manage interfaces.

## Source Lock

[`source.env`](source.env) is the single version lock for the upstream repository, tag, full commit SHA, and module version. Other scripts and documentation do not duplicate these values, avoiding inconsistent version information after an update.

The build also verifies the full commit resolved by the tag and the upstream `version.h`, preventing a moved tag or inconsistent metadata from breaking reproducibility.

## Integration

- [`integrate.sh`](integrate.sh) downloads the pinned source and imports it into `drivers/net/amneziawg/`.
- [`Kconfig`](Kconfig) exposes the module as `CONFIG_AMNEZIAWG=m` in the kernel configuration.
- The integration script updates the kernel `drivers/net/Kconfig` and `drivers/net/Makefile` so the module participates in the normal in-tree build.
- The upstream `tests/` directory used by the external-module build and generated build leftovers are excluded from the prepared kernel tree.
- [`manifest.sh`](manifest.sh) emits declarative JSON used by the common build flow to validate source provenance, required configuration, module name, version, vermagic, and package path.
- DEB, RPM, APK, and Arch packages install the module produced by the same shared kernel compilation.

## Kernel Series Compatibility

| Kernel series | x86_64 | arm64 | Project compatibility work |
| --- | --- | --- | --- |
| `6.12` | Supported | Supported | No series-specific patch |
| `6.18` | Supported | Supported | No series-specific patch |
| `7.1` | Supported | Supported | `CONFIG_IPV6=y`; UDP tunnel socket API adaptation |

Patches are organized by scope:

```text
patches/
├── common/             # Applied to every kernel series
└── <kernel-series>/    # Applied only to the named kernel series
```

The current Linux 7.1 compatibility patch is:

```text
patches/7.1/0001-compat-linux-7.1-udp-tunnel-sock-api.patch
```

Linux 7.1 changed `setup_udp_tunnel_sock()` and `udp_tunnel_sock_release()` from `struct socket` parameters to `struct sock`. The project patch passes `socket->sk` on Linux 7.1 and later while retaining the previous calls for earlier kernels.

Every patch is applied with zero fuzz. Source preparation or update validation fails when patch context drifts.

## Updating the Upstream Version

Run from the repository root:

```bash
bash external/amneziawg/update.sh v<version>
```

The update script:

1. Clones the requested upstream tag.
2. Resolves and validates the full commit SHA.
3. Reads the module version from upstream `src/version.h`.
4. Confirms that the tag and module version match.
5. Validates the `patches/common/` and `patches/<series>/` stacks for each kernel series in order, with fuzz disabled.
6. Updates the tag, commit, and version in `source.env`.

After an update, revalidate the Linux 6.12, 6.18, and 7.1 build matrix on x86_64 and arm64, and confirm that all four package formats still contain the module paths declared by the manifest. If upstream has incorporated a compatibility fix, remove or regenerate the corresponding patch instead of retaining a patch that applies in reverse or requires fuzz.

## Files

| File | Purpose |
| --- | --- |
| `source.env` | Pins the upstream repository, tag, commit, and module version |
| `Kconfig` | Defines the in-tree `CONFIG_AMNEZIAWG` option |
| `integrate.sh` | Downloads, validates, imports, and wires the source into the kernel build |
| `manifest.sh` | Emits declarative module data consumed by the common build flow |
| `update.sh` | Updates the source lock and validates per-series patch stacks |
| `patches/common/` | Compatibility patches shared by every series |
| `patches/<series>/` | Compatibility patches for one kernel series |

%{!?kernel_version:%global kernel_version 0}
%{!?kernel_release:%global kernel_release %{kernel_version}}
%{!?kernel_source_dir:%global kernel_source_dir %{_builddir}/linux}
%{!?kernel_arch:%global kernel_arch x86}
%{!?kernel_make_verbosity:%global kernel_make_verbosity 0}
%global debug_package %{nil}
%global _missing_build_ids_terminate_build 0

Name:           kernel-cloud-bbrv3
Version:        %{kernel_version}
Release:        1
Summary:        Cloud kernel with BBRv3 and custom congestion controls
License:        GPL-2.0-only
URL:            https://github.com/CloudPassenger/Cloud-Kernel-BBRv3
BuildRequires:  bash
BuildRequires:  bc
BuildRequires:  binutils
BuildRequires:  bison
BuildRequires:  elfutils-libelf-devel
BuildRequires:  flex
BuildRequires:  gcc
BuildRequires:  make
BuildRequires:  openssl
BuildRequires:  openssl-devel
BuildRequires:  perl
BuildRequires:  python3
BuildRequires:  rsync
Requires(posttrans): coreutils
Requires(posttrans): dracut
Requires(posttrans): kmod
Requires(posttrans): /usr/bin/kernel-install
Requires(preun): /usr/bin/kernel-install
Recommends:     linux-firmware
Provides:       installonlypkg(kernel)
Provides:       kernel-uname-r = %{kernel_release}
Provides:       kernel-modules-uname-r = %{kernel_release}
AutoReqProv:    no

%description
A cloud-oriented Linux kernel built from upstream Linux, the matching Debian
kernel-team patch set, XanMod network patches, and Cloud-Kernel-BBRv3 custom
patches and configuration.

%package devel
Summary:        Development files for kernel %{kernel_release}
Requires:       gcc
Requires:       make
Requires:       perl
Provides:       kernel-devel-uname-r = %{kernel_release}
AutoReqProv:    no

%description devel
Headers, generated files, scripts, and Module.symvers required to build
external modules for kernel %{kernel_release}.

%prep
:

%build
cd %{kernel_source_dir}
actual_release=$(make -s ARCH=%{kernel_arch} kernelrelease)
if [ "$actual_release" != "%{kernel_release}" ]; then
  echo "error: expected kernel release %{kernel_release}, got $actual_release" >&2
  exit 1
fi
# Refresh host-side build tooling (fixdep, modpost, sign-file, ...) against
# this container's own libc. The vmlinux/*.ko objects were already compiled
# once by build_kernel.sh and are left untouched by this step.
make ARCH=%{kernel_arch} \
  V=%{kernel_make_verbosity} \
  CC=gcc \
  HOSTCC=gcc \
  modules_prepare

%install
cd %{kernel_source_dir}
rm -rf %{buildroot}
mkdir -p %{buildroot}/lib/modules/%{kernel_release}

make ARCH=%{kernel_arch} \
  V=%{kernel_make_verbosity} \
  INSTALL_MOD_PATH=%{buildroot} \
  INSTALL_MOD_STRIP=1 \
  DEPMOD=true \
  modules_install

image_path=$(make -s ARCH=%{kernel_arch} image_name)
install -Dm644 "$image_path" \
  %{buildroot}/lib/modules/%{kernel_release}/vmlinuz
install -Dm644 System.map \
  %{buildroot}/lib/modules/%{kernel_release}/System.map
install -Dm644 .config \
  %{buildroot}/lib/modules/%{kernel_release}/config

if [ -d "arch/%{kernel_arch}/boot/dts" ]; then
  make ARCH=%{kernel_arch} \
    V=%{kernel_make_verbosity} \
    INSTALL_DTBS_PATH=%{buildroot}/lib/modules/%{kernel_release}/dtb \
    dtbs_install
fi

rm -f \
  %{buildroot}/lib/modules/%{kernel_release}/build \
  %{buildroot}/lib/modules/%{kernel_release}/source

make ARCH=%{kernel_arch} run-command \
  V=%{kernel_make_verbosity} \
  KBUILD_RUN_COMMAND="${PWD}/scripts/package/install-extmod-build %{buildroot}/usr/src/kernels/%{kernel_release}"
# RPM's brp-mangle-shebangs refuses ambiguous "#!/usr/bin/env python" shebangs;
# fix them up explicitly instead of patching the vendored kernel source.
find %{buildroot}/usr/src/kernels/%{kernel_release} -type f -print0 \
  | xargs -0 -r -I{} sh -c '\
      [ "$(head -n1 "{}" 2>/dev/null)" = "#!/usr/bin/env python" ] \
        && sed -i "1s@.*@#!/usr/bin/env python3@" "{}"; :'
mkdir -p %{buildroot}/lib/modules/%{kernel_release}
ln -s /usr/src/kernels/%{kernel_release} \
  %{buildroot}/lib/modules/%{kernel_release}/build

{
  echo "/lib/modules/%{kernel_release}"
  for index in alias alias.bin builtin.alias.bin builtin.bin dep dep.bin \
    devname softdep symbols symbols.bin weakdep; do
    echo "%%ghost /lib/modules/%{kernel_release}/modules.${index}"
  done
  for boot_file in vmlinuz System.map config; do
    echo "%%ghost /boot/${boot_file}-%{kernel_release}"
  done
  echo "%%ghost /boot/initramfs-%{kernel_release}.img"
  if [ -d "%{buildroot}/lib/modules/%{kernel_release}/dtb" ]; then
    find "%{buildroot}/lib/modules/%{kernel_release}/dtb" \
      -printf "%%%%ghost /boot/dtb-%{kernel_release}/%%P\n"
  fi
  echo "%%exclude /lib/modules/%{kernel_release}/build"
} > %{buildroot}/kernel-cloud-bbrv3.list

%posttrans
/usr/sbin/depmod -a %{kernel_release}
/usr/bin/kernel-install add %{kernel_release} /lib/modules/%{kernel_release}/vmlinuz
for boot_file in vmlinuz System.map config; do
  source_file=/lib/modules/%{kernel_release}/${boot_file}
  target_file=/boot/${boot_file}-%{kernel_release}
  if ! cmp --silent "$source_file" "$target_file"; then
    cp -f "$source_file" "$target_file"
  fi
done
if [ -d /lib/modules/%{kernel_release}/dtb ]; then
  rm -rf /boot/dtb-%{kernel_release}
  cp -a /lib/modules/%{kernel_release}/dtb /boot/dtb-%{kernel_release}
fi

%preun
if [ "$1" -eq 0 ]; then
  /usr/bin/kernel-install remove %{kernel_release} || :
fi

%files -f %{buildroot}/kernel-cloud-bbrv3.list
%exclude /kernel-cloud-bbrv3.list

%files devel
/usr/src/kernels/%{kernel_release}
/lib/modules/%{kernel_release}/build

%changelog
* Mon Aug 10 2026 Cloud Kernel BBRv3 <noreply@example.invalid> - %{kernel_version}-1
- Build one generic RPM for Fedora and Enterprise Linux targets.

#!/usr/bin/env bash
# Sign release RPMs and the checksum manifest with a protected OpenPGP key.
set -euo pipefail

usage() {
  printf 'usage: %s <assets-dir> <private-key-file> <expected-fingerprint> [passphrase-file]\n' "$(basename "$0")" >&2
  exit 1
}

[ "$#" -ge 3 ] && [ "$#" -le 4 ] || usage

assets_dir=$(realpath "$1")
private_key_file=$(realpath "$2")
expected_fingerprint=${3//[[:space:]]/}
passphrase_file=${4:-}

if [ -n "$passphrase_file" ]; then
  passphrase_file=$(realpath "$passphrase_file")
fi

if [ ! -d "$assets_dir" ]; then
  printf 'error: release assets directory not found: %s\n' "$assets_dir" >&2
  exit 1
fi
if [ ! -s "$private_key_file" ]; then
  printf 'error: OpenPGP private key not found: %s\n' "$private_key_file" >&2
  exit 1
fi
if [ -z "$expected_fingerprint" ]; then
  printf 'error: expected OpenPGP fingerprint is required\n' >&2
  exit 1
fi
if [ -n "$passphrase_file" ] && [ ! -f "$passphrase_file" ]; then
  printf 'error: OpenPGP passphrase file not found: %s\n' "$passphrase_file" >&2
  exit 1
fi

expected_fingerprint=${expected_fingerprint^^}
umask 077
gnupg_home=$(mktemp -d)
rpm_db=$(mktemp -d)
cleanup() {
  rm -rf "$gnupg_home" "$rpm_db"
}
trap cleanup EXIT

export GNUPGHOME=$gnupg_home
gpg --batch --import "$private_key_file"
actual_fingerprint=$(gpg --batch --with-colons --list-secret-keys \
  | sed -n 's/^fpr:::::::::\([^:]*\):$/\1/p' \
  | sed -n '1p')
actual_fingerprint=${actual_fingerprint^^}
if [ "$actual_fingerprint" != "$expected_fingerprint" ]; then
  printf 'error: imported OpenPGP fingerprint %s does not match expected %s\n' \
    "$actual_fingerprint" "$expected_fingerprint" >&2
  exit 1
fi

public_key=$assets_dir/cloud-kernel-signing.asc
gpg --batch --armor --export "$expected_fingerprint" > "$public_key"

rpm_sign_args=(
  --define "_openpgp_sign_id $expected_fingerprint"
  --define "_gpg_name $expected_fingerprint"
  --define "_gpg_path $GNUPGHOME"
)
gpg_args=(--batch --yes --no-tty --pinentry-mode loopback)
if [ -n "$passphrase_file" ]; then
  rpm_sign_args+=(--define "_gpg_sign_cmd_extra_args --batch --no-tty --pinentry-mode loopback --passphrase-file $passphrase_file")
  gpg_args+=(--passphrase-file "$passphrase_file")
else
  rpm_sign_args+=(--define "_gpg_sign_cmd_extra_args --batch --no-tty")
fi

shopt -s nullglob
rpm_packages=("$assets_dir"/*.rpm)
for package in "${rpm_packages[@]}"; do
  rpmsign "${rpm_sign_args[@]}" --addsign "$package"
done

rpm --dbpath "$rpm_db" --initdb
rpmkeys --dbpath "$rpm_db" --import "$public_key"
for package in "${rpm_packages[@]}"; do
  rpmkeys --dbpath "$rpm_db" --checksig "$package"
done

manifest=$assets_dir/SHA256SUMS
signature=$assets_dir/SHA256SUMS.asc
rm -f "$manifest" "$signature"
(
  cd "$assets_dir"
  export LC_ALL=C
  for asset in *; do
    [ -f "$asset" ] || continue
    case "$asset" in
      SHA256SUMS|SHA256SUMS.asc) continue ;;
    esac
    sha256sum -- "$asset"
  done
) > "$manifest"

gpg "${gpg_args[@]}" \
  --local-user "$expected_fingerprint" \
  --armor \
  --detach-sign \
  --output "$signature" \
  "$manifest"

gpg --batch --no-default-keyring \
  --keyring "$gnupg_home/release-keyring.gpg" \
  --import "$public_key"
gpgv --keyring "$gnupg_home/release-keyring.gpg" "$signature" "$manifest"

printf 'Signed %d RPM package(s) and release manifest with %s\n' \
  "${#rpm_packages[@]}" "$expected_fingerprint"

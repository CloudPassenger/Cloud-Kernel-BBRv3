#!/usr/bin/env bash
# Install the pinned pahole version used by every kernel package lane.
set -euo pipefail

work_dir=${1:-${RUNNER_TEMP:-/tmp}/dwarves-v1.31}

if command -v pahole >/dev/null 2>&1 && [ "$(pahole --version)" = "v1.31" ]; then
  printf 'Using existing %s\n' "$(pahole --version)"
  exit 0
fi

rm -rf "$work_dir"
git clone --branch v1.31 --depth=1 --recurse-submodules \
  https://github.com/acmel/dwarves.git "$work_dir"
cmake -S "$work_dir" -B "$work_dir/build" \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=OFF \
  -DLIBBPF_EMBEDDED=ON \
  -DCMAKE_INSTALL_PREFIX=/usr/local
cmake --build "$work_dir/build" --parallel "$(nproc)"
cmake --install "$work_dir/build"
pahole --version

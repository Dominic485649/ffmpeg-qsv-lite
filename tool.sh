#!/usr/bin/env bash
set -euo pipefail

echo "== Update apt =="
sudo apt update
sudo apt full-upgrade -y

echo
echo "== Install build toolchain =="
sudo apt install -y --no-install-recommends \
  build-essential \
  autoconf automake libtool make cmake meson ninja-build \
  pkg-config nasm yasm \
  git curl ca-certificates \
  python3 gettext gperf \
  mingw-w64 mingw-w64-tools \
  binutils-mingw-w64-x86-64 \
  gcc-mingw-w64-x86-64 g++-mingw-w64-x86-64 \
  gcc-mingw-w64-x86-64-posix g++-mingw-w64-x86-64-posix \
  mingw-w64-x86-64-dev

echo
echo "== Check versions =="
echo "[MinGW GCC]"
x86_64-w64-mingw32-gcc-posix --version | head -n 1

echo
echo "[MinGW G++]"
x86_64-w64-mingw32-g++-posix --version | head -n 1

echo
echo "[CMake]"
cmake --version | head -n 1

echo
echo "[Meson]"
meson --version

echo
echo "Done."

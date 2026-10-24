#!/usr/bin/env bash
# Install the pinned uv into .tools/, verifying the release checksum.
set -euo pipefail

version="0.13.5"
root="$(cd "$(dirname "$0")/.." && pwd)"
tools="$root/.tools"
dest="$tools/uv-$version"

case "$(uname -s)-$(uname -m)" in
  Darwin-arm64)
    asset="uv-aarch64-apple-darwin.tar.gz"
    sha="743f85035a1996ecb350659e01cd9faea9709829be09b1b4b03c73eaf3c9cd73"
    ;;
  Darwin-x86_64)
    asset="uv-x86_64-apple-darwin.tar.gz"
    sha="b0f52b0e3945b4107d89024ea38e625683011fbfc05a0d98f9fa2d6dcee28c66"
    ;;
  Linux-x86_64)
    asset="uv-x86_64-unknown-linux-gnu.tar.gz"
    sha="f68d291c75783122dad58ab77def0e13f3233f358731db5d6d7e8715603b928f"
    ;;
  Linux-aarch64|Linux-arm64)
    asset="uv-aarch64-unknown-linux-gnu.tar.gz"
    sha="4bb69cf95ed13f23713bb7bc09f241896ea0c75b7c557e615a20604b82f9c403"
    ;;
  *)
    echo "unsupported platform: $(uname -s)-$(uname -m)" >&2
    exit 1
    ;;
esac

if [ -x "$dest/uv" ] && "$dest/uv" --version 2>/dev/null | grep -q " $version "; then
  echo "uv $version already installed at $dest"
  exit 0
fi

mkdir -p "$tools"
tarball="$tools/$asset"
curl --fail --show-error --location --retry 3 \
  "https://github.com/astral-sh/uv/releases/download/$version/$asset" \
  -o "$tarball"

if command -v shasum >/dev/null 2>&1; then
  actual=$(shasum -a 256 "$tarball" | awk '{print $1}')
else
  actual=$(sha256sum "$tarball" | awk '{print $1}')
fi

if [ "$actual" != "$sha" ]; then
  echo "checksum mismatch for $asset" >&2
  echo "expected: $sha" >&2
  echo "actual:   $actual" >&2
  exit 1
fi

rm -rf "$dest"
mkdir -p "$dest"
tar -xzf "$tarball" -C "$dest" --strip-components=1
rm -f "$tarball"
"$dest/uv" --version

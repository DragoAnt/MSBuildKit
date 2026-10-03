#!/bin/sh
# Builds the release zip of the kit: <out>/msbuildkit-<version>.zip and its .sha256.
# Usage: sh tools/pack-kit.sh <version> [out-dir]
set -eu

[ $# -ge 1 ] || { echo "usage: sh tools/pack-kit.sh <version> [out-dir]" >&2; exit 1; }
version="${1#v}"
here=$(cd "$(dirname "$0")/.." && pwd)
out="${2:-$here/dist}"
mkdir -p "$out"
out=$(cd "$out" && pwd)
name="msbuildkit-$version.zip"

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT INT TERM
cp -R "$here/kit/.toolkit" "$stage/.toolkit"
printf '%s\n' "$version" > "$stage/.toolkit/kit.version"
find "$stage" -name '*.sh' -exec chmod +x {} +

rm -f "$out/$name" "$out/$name.sha256"
if command -v zip >/dev/null 2>&1; then
  (cd "$stage" && zip -qrX "$out/$name" .toolkit)
elif [ -x /c/Windows/System32/tar.exe ]; then
  (cd "$stage" && /c/Windows/System32/tar.exe -a -cf "$(cygpath -w "$out/$name")" .toolkit)
else
  echo "pack-kit: install zip" >&2; exit 1
fi

if command -v sha256sum >/dev/null 2>&1; then sha=$(sha256sum "$out/$name" | cut -d' ' -f1)
else sha=$(shasum -a 256 "$out/$name" | cut -d' ' -f1); fi
printf '%s  %s\n' "$sha" "$name" > "$out/$name.sha256"
echo "$out/$name"
echo "sha256 $sha"

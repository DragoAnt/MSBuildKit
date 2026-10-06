#!/bin/sh
# mskit-manager: builds and tests the tool, packs it, installs the packed tool into a tool path and runs it.
# Usage: sh tests/manager.sh [--version <version>] [--out <dir>] [--no-nuget-fallback]
set -eu

here=$(cd "$(dirname "$0")/.." && pwd)
version="0.0.0-local.$(date +%s)"
out="$here/dist/manager"
fallback=fallback
while [ $# -gt 0 ]; do
  case "$1" in
    --version) version="$2"; shift 2 ;;
    --out) mkdir -p "$2"; out=$(cd "$2" && pwd); shift 2 ;;
    --no-nuget-fallback) fallback=no-fallback; shift ;;
    *) echo "usage: sh tests/manager.sh [--version <version>] [--out <dir>] [--no-nuget-fallback]" >&2; exit 1 ;;
  esac
done
rm -rf "$out"; mkdir -p "$out"

failures=0
pass() { echo "PASS  $*"; }
bad() { echo "FAIL  $*"; failures=$((failures+1)); }

. "$here/tests/nuget-isolation.sh"
ni_begin manager "$fallback"

cd "$here/manager"
dotnet build DragoAnt.MSBuildKit.Manager.slnx -c Release -nologo
dotnet test --solution DragoAnt.MSBuildKit.Manager.slnx -c Release --no-build \
  --coverage --coverage-output-format cobertura --report-trx --report-xunit-junit \
  --results-directory "$out/TestResults" 2>&1 | tee "$out/test.log"
grep -q 'Test run summary: Passed!' "$out/test.log" && pass "the tool's tests pass on Microsoft.Testing.Platform" || bad "the tool's tests (see $out/test.log)"

dotnet pack src/DragoAnt.MSBuildKit.Manager/DragoAnt.MSBuildKit.Manager.csproj -c Release -nologo -o "$out/feed" "-p:Version=$version"
dotnet tool install --tool-path "$out/tools" --add-source "$out/feed" DragoAnt.MSBuildKit.Manager --version "$version"
"$out/tools/mskit-manager" --help
"$out/tools/mskit-manager" status --json > "$out/status.json"
cat "$out/status.json"
tr -d '\r' < "$out/status.json" | grep -q "\"version\": \"$version\"" && pass "the installed tool reports $version" || bad "status --json did not report $version"

ni_verify "$out" "$out/feed"

echo
if [ "$failures" -eq 0 ]; then echo "manager: all checks passed"; else echo "manager: $failures failure(s)"; exit 1; fi

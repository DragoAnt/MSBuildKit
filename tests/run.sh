#!/bin/sh
# Kit self-test: installs the working-tree kit into the sample and the fixtures with update.sh,
# then checks the version scheme, the sample's build/test/pack output and every package check.
# Restores into a global-packages folder of its own (tests/nuget-isolation.sh) unless NUGET_PACKAGES is set.
# Usage: sh tests/run.sh [--skip-tests] [--no-nuget-fallback]
set -eu

here=$(cd "$(dirname "$0")/.." && pwd)
kit="$here/kit"
sample="$here/samples/MinimalLibrary"
fixtures="$here/tests/fixtures/PackageChecks"
readme_fixture="$here/tests/fixtures/PackageReadme"
tfm_fixture="$here/tests/fixtures/TfmConstants"
icon_fixture="$here/tests/fixtures/PackageIcon"
out="$here/dist/selftest"
run_tests=1
nuget_fallback=fallback
for arg in "$@"; do
  case "$arg" in
    --skip-tests) run_tests=0 ;;
    --no-nuget-fallback) nuget_fallback=no-fallback ;;
    *) echo "usage: sh tests/run.sh [--skip-tests] [--no-nuget-fallback]" >&2; exit 1 ;;
  esac
done
rm -rf "$out"; mkdir -p "$out"

failures=0
pass() { echo "PASS  $*"; }
bad() { echo "FAIL  $*"; failures=$((failures+1)); }

. "$here/tests/nuget-isolation.sh"
ni_begin "$out-nuget-packages" "$nuget_fallback"
trap ni_end EXIT

for root in "$sample" "$fixtures" "$readme_fixture" "$tfm_fixture" "$icon_fixture"; do
  sh "$kit/.toolkit/update.sh" --source "$kit" --root "$root" > "$out/install.log" || { cat "$out/install.log"; exit 1; }
done
pass "update.sh installed the kit into the sample and the fixtures"
. "$here/tests/update-self.sh"

lib="$sample/src/DragoAnt.Samples.MinimalLibrary/DragoAnt.Samples.MinimalLibrary.csproj"
clean_env="env -u GITHUB_ACTIONS -u GITHUB_RUN_ID -u GITHUB_RUN_NUMBER -u GITHUB_REF -u GITHUB_REF_NAME -u GITHUB_REF_TYPE -u GITHUB_EVENT_NAME -u GITHUB_HEAD_REF -u GITHUB_SHA -u GITHUB_REPOSITORY"
ci_env="GITHUB_ACTIONS=true GITHUB_RUN_ID=24000000001 GITHUB_RUN_NUMBER=7"

version_case() {
  name="$1"; expected="$2"; shift 2
  actual=$($clean_env $ci_env "$@" dotnet msbuild "$lib" -nologo -getProperty:Version 2>&1 | tr -d '\r' | tail -n 1)
  if [ "$actual" = "$expected" ]; then pass "version $name -> $actual"; else bad "version $name: expected '$expected', got '$actual'"; fi
}

local_version=$($clean_env dotnet msbuild "$lib" -nologo -getProperty:Version | tr -d '\r' | tail -n 1)
[ "$local_version" = "9999.0.0" ] && pass "version local -> $local_version" || bad "version local: expected 9999.0.0, got '$local_version'"
version_case "branch main" "0.1.0-ci.7" GITHUB_EVENT_NAME=push GITHUB_REF_TYPE=branch GITHUB_REF_NAME=main GITHUB_REF=refs/heads/main
version_case "branch feature" "0.1.0-ci.7" GITHUB_EVENT_NAME=push GITHUB_REF_TYPE=branch GITHUB_REF_NAME=feat/x GITHUB_REF=refs/heads/feat/x
version_case "pull request 15" "0.1.0-pr.15.7" GITHUB_EVENT_NAME=pull_request GITHUB_REF_TYPE=branch GITHUB_REF_NAME=15/merge GITHUB_REF=refs/pull/15/merge GITHUB_HEAD_REF=feat/x
version_case "tag v2.0.0" "2.0.0" GITHUB_EVENT_NAME=release GITHUB_REF_TYPE=tag GITHUB_REF_NAME=v2.0.0 GITHUB_REF=refs/tags/v2.0.0
version_case "tag 2.0.0" "2.0.0" GITHUB_EVENT_NAME=release GITHUB_REF_TYPE=tag GITHUB_REF_NAME=2.0.0 GITHUB_REF=refs/tags/2.0.0
version_case "tag v2.1.0-beta.1" "2.1.0-beta.1" GITHUB_EVENT_NAME=release GITHUB_REF_TYPE=tag GITHUB_REF_NAME=v2.1.0-beta.1 GITHUB_REF=refs/tags/v2.1.0-beta.1
explicit=$($clean_env $ci_env GITHUB_EVENT_NAME=release GITHUB_REF_TYPE=tag GITHUB_REF_NAME=v9.9.9 GITHUB_REF=refs/tags/v9.9.9 dotnet msbuild "$lib" -nologo -p:Version=3.4.5 -getProperty:Version 2>&1 | tr -d '' | tail -n 1)
[ "$explicit" = "3.4.5" ] && pass "version -p:Version=3.4.5 on a tag build -> $explicit (caller wins)" || bad "explicit -p:Version: expected 3.4.5, got '$explicit'"

if $clean_env $ci_env GITHUB_EVENT_NAME=release GITHUB_REF_TYPE=tag GITHUB_REF_NAME=release-x GITHUB_REF=refs/tags/release-x \
    dotnet restore "$lib" -nologo > "$out/invalid-tag.log" 2>&1; then
  bad "tag release-x: restore succeeded, expected MSKITVER006"
elif grep -q "MSKITVER006" "$out/invalid-tag.log"; then
  pass "tag release-x -> restore fails with MSKITVER006"
else
  bad "tag release-x: restore failed without MSKITVER006 (see $out/invalid-tag.log)"
fi

$clean_env dotnet build "$sample/MinimalLibrary.slnx" -c Release -nologo > "$out/build.log" 2>&1 && pass "sample builds" || { bad "sample build (see $out/build.log)"; tail -n 30 "$out/build.log"; }

if [ "$run_tests" -eq 1 ]; then
  if (cd "$sample" && $clean_env dotnet test --solution MinimalLibrary.slnx -c Release --no-build \
      --coverage --coverage-output-format cobertura --report-trx --report-xunit-junit --results-directory "$out/TestResults") > "$out/test.log" 2>&1; then
    pass "sample tests pass"
  else
    bad "sample tests (see $out/test.log)"; tail -n 30 "$out/test.log"
  fi
  ls "$out/TestResults"/*.trx > /dev/null 2>&1 && pass "TRX written" || bad "no TRX in $out/TestResults"
  find "$out/TestResults" -iname "*junit*" | grep -q . && pass "JUnit written" || bad "no JUnit report in $out/TestResults"
  find "$out/TestResults" -name '*.cobertura.xml' | grep -q . && pass "cobertura coverage written" || bad "no cobertura report in $out/TestResults"
fi

$clean_env $ci_env GITHUB_EVENT_NAME=release GITHUB_REF_TYPE=tag GITHUB_REF_NAME=v0.1.0 GITHUB_REF=refs/tags/v0.1.0 GITHUB_REPOSITORY=DragoAnt/MSBuildKit GITHUB_SERVER_URL=https://github.com \
  dotnet pack "$sample/MinimalLibrary.slnx" -c Release -nologo -o "$out/packages" > "$out/pack.log" 2>&1 \
  && pass "sample packs on a CI tag build with the checks as errors" || { bad "sample pack (see $out/pack.log)"; tail -n 30 "$out/pack.log"; }

command -v unzip >/dev/null 2>&1 || { echo "self-test: unzip is required"; exit 1; }
nupkg="$out/packages/DragoAnt.Samples.MinimalLibrary.0.1.0.nupkg"
if [ -f "$nupkg" ]; then
  unzip -p "$nupkg" DragoAnt.Samples.MinimalLibrary.nuspec | tr -d '\r' > "$out/sample.nuspec"
  unzip -l "$nupkg" | awk 'NR>3 {print $4}' | grep -v '^$' > "$out/sample.files"
  for needle in '<version>0.1.0</version>' '<license type="expression">MIT</license>' '<icon>icon.png</icon>' '<readme>readme.md</readme>' \
      '<projectUrl>https://github.com/DragoAnt/MSBuildKit</projectUrl>' '<releaseNotes>https://github.com/DragoAnt/MSBuildKit/releases/tag/v0.1.0</releaseNotes>' \
      '<copyright>Copyright (c) ' '<tags>sample msbuild nuget packaging</tags>' 'repository type="git" url="https://github.com/DragoAnt/MSBuildKit' 'commit="'; do
    grep -qF "$needle" "$out/sample.nuspec" && pass "nuspec has $needle" || bad "nuspec lacks $needle"
  done
  for f in icon.png readme.md; do grep -qx "$f" "$out/sample.files" && pass "nupkg contains $f" || bad "nupkg lacks $f"; done
  grep -q '^lib/[^/]*/DragoAnt\.Samples\.MinimalLibrary\.xml$' "$out/sample.files" && pass "nupkg contains the XML documentation" || bad "nupkg lacks the XML documentation"
  [ -f "$out/packages/DragoAnt.Samples.MinimalLibrary.0.1.0.snupkg" ] && pass "snupkg produced" || bad "no snupkg"
else
  bad "no $nupkg"
fi

$clean_env dotnet pack "$fixtures/PackageChecks.slnx" -c Release -nologo -o "$out/fixtures" -p:MSKit_PackageChecksAsErrors=False > "$out/checks.log" 2>&1 || true
for code in 001 002 003 004 005 006 007 008 009 010 011 012 013 014 015 016 017 018 019; do
  grep -q "warning MSKITPKG$code" "$out/checks.log" && pass "check MSKITPKG$code fires" || bad "check MSKITPKG$code did not fire (see $out/checks.log)"
done
grep -q "<div>" "$out/checks.log" && bad "HTML inside a code fence was reported" || pass "HTML inside a code fence is ignored"

if $clean_env $ci_env GITHUB_EVENT_NAME=push GITHUB_REF_TYPE=branch GITHUB_REF_NAME=main GITHUB_REF=refs/heads/main \
    dotnet pack "$fixtures/BadPackage/BadPackage.csproj" -c Release -nologo -o "$out/fixtures-ci" > "$out/checks-ci.log" 2>&1; then
  bad "the checks did not fail the CI pack"
else
  grep -q "error MSKITPKG001" "$out/checks-ci.log" && pass "checks are errors on CI" || bad "CI pack failed without MSKITPKG errors (see $out/checks-ci.log)"
fi

$clean_env dotnet pack "$fixtures/BadPackage/BadPackage.csproj" -c Release -nologo -o "$out/fixtures-skip" \
  "-p:MSKit_SkipPackageChecks=All" > "$out/checks-skip.log" 2>&1 || true
grep -q "MSKITPKG" "$out/checks-skip.log" && bad "MSKit_SkipPackageChecks=All did not silence the checks" || pass "MSKit_SkipPackageChecks=All silences the checks"

. "$here/tests/package-readme.sh"
. "$here/tests/tfm-constants.sh"
. "$here/tests/package-icon.sh"
. "$here/tests/codes.sh"
. "$here/tests/docs.sh"
ni_verify "$out" "$out"

echo
if [ "$failures" -eq 0 ]; then echo "self-test: all checks passed"; else echo "self-test: $failures failure(s)"; exit 1; fi

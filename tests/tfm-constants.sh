# TfmConstants: IsNETxx follows the TargetFramework a csproj sets, single or multi-targeted.
# Sourced by tests/run.sh: uses its pass, bad, $out, $here, $clean_env and $tfm_fixture.

tfm_prop() {
  $clean_env dotnet msbuild "$tfm_fixture/$1/$1.csproj" -nologo "-getProperty:$2" ${3:+"$3"} 2>&1 | tr -d '\r' | tail -n 1
}
tfm_expect() {
  actual=$(tfm_prop "$1" "$2" "${4:-}")
  [ "$actual" = "$3" ] && pass "tfm $1${4:+ $4}: $2='$actual'" || bad "tfm $1${4:+ $4}: $2 expected '$3', got '$actual'"
}
tfm_validate() {
  name="$1"; expect="$2"; shift 2
  if $clean_env dotnet msbuild "$tfm_fixture/$name/$name.csproj" -nologo -t:ValidateXUnitV3TFM "$@" > "$out/tfm-$name.log" 2>&1; then
    [ "$expect" = ok ] && pass "tfm $name passes MSKIT_TEST005" || bad "tfm $name: expected MSKIT_TEST005, the check passed"
  elif grep -q "MSKIT_TEST005" "$out/tfm-$name.log"; then
    [ "$expect" = fail ] && pass "tfm $name fails with MSKIT_TEST005" || bad "tfm $name: false MSKIT_TEST005 (see $out/tfm-$name.log)"
  else
    bad "tfm $name: the check failed without MSKIT_TEST005 (see $out/tfm-$name.log)"
  fi
}

for v in 8 9 10; do
  tfm_expect "Net$v.Tests" IsNET8_OR_GREATER True
  tfm_expect "Net$v.Tests" IsNET$v True
  tfm_expect "Net$v.Tests" TargetFrameworkVersionMajor "$v"
  tfm_validate "Net$v.Tests" ok
done
tfm_expect Net8.Tests TestingPlatformDotnetTestSupport True
tfm_expect Net9.Tests TestingPlatformDotnetTestSupport True
tfm_expect Net10.Tests TestingPlatformDotnetTestSupport ""

tfm_expect Net6.Tests IsNET8_OR_GREATER ""
tfm_validate Net6.Tests fail

# Multi-targeted: the outer build has no TargetFramework; each inner build gets it as a global
# property, so the constants are right in the props phase too (a csproj property condition).
tfm_expect Multi.Tests IsNET8 ""
tfm_expect Multi.Tests IsNET8 True -p:TargetFramework=net8.0
tfm_expect Multi.Tests FixturePropsPhaseIsNet8 True -p:TargetFramework=net8.0
tfm_expect Multi.Tests IsNET10_OR_GREATER True -p:TargetFramework=net10.0
tfm_expect Multi.Tests IsNET8 "" -p:TargetFramework=net10.0
tfm_validate Multi.Tests ok -p:TargetFramework=net8.0

$clean_env dotnet build "$tfm_fixture/Net10.Tests/Net10.Tests.csproj" -c Release -nologo > "$out/tfm-build.log" 2>&1 \
  && pass "tfm a single-TFM net10.0 xunit.v3 test project builds" \
  || { bad "tfm Net10.Tests build (see $out/tfm-build.log)"; grep -m 3 "error" "$out/tfm-build.log"; }

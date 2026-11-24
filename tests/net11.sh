# net11.0: a consumer builds, tests and packs it, alone and multi-targeted, and restore gets its apphost pack.
# Only SDK 11 or later can build net11.0 (NETSDK1045), so an older SDK prints SKIP; MSBUILDKIT_TESTS_SDK_MAJOR
# makes a run on any other SDK fail, so a CI job cannot skip these checks unnoticed.
# Sourced by tests/run.sh after tests/apphost.sh: uses its pass, bad, $here, $out, $sample, $clean_env, $ci_env,
# $tfm_fixture, $apphost_fixture, $ah_host, ah_downloads and ni_native.

n11_sdk=$(cd "$here" && dotnet --version | tr -d '\r')
n11_major=${n11_sdk%%.*}
if [ -n "${MSBUILDKIT_TESTS_SDK_MAJOR:-}" ]; then
  [ "$n11_major" = "$MSBUILDKIT_TESTS_SDK_MAJOR" ] \
    && pass "net11 the run uses SDK $n11_sdk" \
    || bad "net11 the run uses SDK $n11_sdk, expected $MSBUILDKIT_TESTS_SDK_MAJOR"
fi

# n11_copy <consumer> <copy> <file with TargetFrameworks, relative> <tfms>
n11_copy() {
  rm -rf "$2"; mkdir -p "$2"
  (cd "$1" && tar -cf - --exclude=bin --exclude=obj .) | tar -xf - -C "$2"
  sed "s#<TargetFrameworks>.*</TargetFrameworks>#<TargetFrameworks>$4</TargetFrameworks>#" "$2/$3" > "$2/$3.new"
  mv "$2/$3.new" "$2/$3"
}

n11_case() {
  n_name=$1; n_tfms=$2; n_dir="$out/net11-$n_name"; n_log="$out/net11-$n_name"
  n11_copy "$sample" "$n_dir" Directory.Build.props "$n_tfms"
  printf '{\n  "sdk": { "version": "%s", "rollForward": "latestFeature" },\n  "test": { "runner": "Microsoft.Testing.Platform" }\n}\n' \
    "$n11_sdk" > "$n_dir/global.json"

  if (cd "$n_dir" && $clean_env dotnet build MinimalLibrary.slnx -c Release -nologo) > "$n_log-build.log" 2>&1; then
    pass "net11 $n_tfms builds"
  else
    bad "net11 $n_tfms build (see $n_log-build.log)"; grep -m 5 "error" "$n_log-build.log" || true; return 0
  fi

  if (cd "$n_dir" && $clean_env dotnet test --solution MinimalLibrary.slnx -c Release --no-build \
      --coverage --coverage-output-format cobertura --report-trx --results-directory "$n_dir/TestResults") > "$n_log-test.log" 2>&1; then
    pass "net11 $n_tfms tests pass"
  else
    bad "net11 $n_tfms tests (see $n_log-test.log)"
  fi

  if (cd "$n_dir" && $clean_env $ci_env GITHUB_EVENT_NAME=release GITHUB_REF_TYPE=tag GITHUB_REF_NAME=v0.1.0 GITHUB_REF=refs/tags/v0.1.0 \
      GITHUB_REPOSITORY=DragoAnt/MSBuildKit GITHUB_SERVER_URL=https://github.com \
      dotnet pack MinimalLibrary.slnx -c Release -nologo -o "$n_dir/packages") > "$n_log-pack.log" 2>&1; then
    pass "net11 $n_tfms packs with the checks as errors"
  else
    bad "net11 $n_tfms pack (see $n_log-pack.log)"; grep -m 5 "error" "$n_log-pack.log" || true
  fi

  for n_tfm in $(printf '%s' "$n_tfms" | tr ';' ' '); do
    grep -q "($n_tfm|[^)]*) passed" "$n_log-test.log" \
      && pass "net11 $n_tfms: the tests ran on $n_tfm" || bad "net11 $n_tfms: no passed test run on $n_tfm (see $n_log-test.log)"
    unzip -l "$n_dir/packages/DragoAnt.Samples.MinimalLibrary.0.1.0.nupkg" 2>/dev/null | grep -q "lib/$n_tfm/DragoAnt\.Samples\.MinimalLibrary\.dll" \
      && pass "net11 $n_tfms: the package has lib/$n_tfm" || bad "net11 $n_tfms: the package lacks lib/$n_tfm"
  done
}

if [ "$n11_major" -lt 11 ]; then
  echo "SKIP  net11.0 builds (SDK $n11_sdk cannot build net11.0)"
else
  n11_case single "net11.0"
  n11_case multi "net8.0;net10.0;net11.0"

  (cd "$here" && $clean_env dotnet build "$tfm_fixture/Net11.Tests/Net11.Tests.csproj" -c Release -nologo) > "$out/net11-tfm-build.log" 2>&1 \
    && pass "net11 a single-TFM net11.0 xunit.v3 test project builds" \
    || { bad "net11 Net11.Tests build (see $out/net11-tfm-build.log)"; grep -m 3 "error" "$out/net11-tfm-build.log" || true; }

  n_ah="$out/net11-apphost"
  n11_copy "$apphost_fixture" "$n_ah" AppHost.Tests/AppHost.Tests.csproj "net8.0;net10.0;net11.0"
  mkdir -p "$out/net11-apphost-packs"
  n_ah_props="-p:NetCoreTargetingPackRoot=$(ni_native "$out/net11-apphost-packs") -p:AllowMissingPrunePackageData=true -p:DisableTransitiveFrameworkReferenceDownloads=true"
  if (cd "$here" && $clean_env dotnet restore "$n_ah/AppHost.Tests/AppHost.Tests.csproj" -nologo $n_ah_props) > "$out/net11-apphost-restore.log" 2>&1; then
    ah_downloads "$n_ah/AppHost.Tests/obj/project.assets.json" > "$out/net11-apphost-downloads.txt"
    grep -qx "net11.0 $ah_host" "$out/net11-apphost-downloads.txt" \
      && pass "net11 restore downloads $ah_host for net11.0" \
      || bad "net11 restore does not download $ah_host for net11.0 (see $out/net11-apphost-downloads.txt)"
  else
    bad "net11 apphost restore (see $out/net11-apphost-restore.log)"
  fi
  if (cd "$here" && $clean_env dotnet build "$n_ah/AppHost.Tests/AppHost.Tests.csproj" -c Release -nologo --no-restore $n_ah_props) > "$out/net11-apphost-build.log" 2>&1; then
    ls "$n_ah/AppHost.Tests/obj/Release/net11.0"/apphost* > /dev/null 2>&1 \
      && pass "net11 net11.0 has an apphost" || bad "net11 net11.0 has no apphost in obj/Release/net11.0"
  else
    bad "net11 apphost build (see $out/net11-apphost-build.log)"
  fi
fi

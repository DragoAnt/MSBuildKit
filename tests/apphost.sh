# AppHost: restore and build of a multi-targeted xunit.v3 test project agree on UseAppHost, so restore downloads
# the apphost pack on every TFM; an empty packs root stands in for an image whose packs do not match the SDK.
# Sourced by tests/run.sh: uses its pass, bad, $out, $clean_env, $apphost_fixture and ni_native.

ah_proj="$apphost_fixture/AppHost.Tests/AppHost.Tests.csproj"
ah_packs="$out/apphost-packs"
rm -rf "$apphost_fixture"/*/bin "$apphost_fixture"/*/obj "$ah_packs"; mkdir -p "$ah_packs"
ah_props="-p:NetCoreTargetingPackRoot=$(ni_native "$ah_packs") -p:AllowMissingPrunePackageData=true -p:DisableTransitiveFrameworkReferenceDownloads=true"
ah_rid=$($clean_env dotnet msbuild "$ah_proj" -nologo -getProperty:NETCoreSdkRuntimeIdentifier 2>&1 | tr -d '\r' | tail -n 1)
ah_host="Microsoft.NETCore.App.Host.$ah_rid"

# Prints "<tfm> <package>" for every downloadDependencies entry of project.assets.json.
ah_downloads() {
  tr -d '\r' < "$1" | awk '
    /^ *"net[0-9.]+": \{/ { t = $1; gsub(/[":]/, "", t) }
    /"downloadDependencies"/ { d = 1; next }
    d && /"name":/ { n = $2; gsub(/[",]/, "", n); print t, n }
    d && /^ *\]/ { d = 0 }'
}

if $clean_env dotnet restore "$ah_proj" -nologo $ah_props > "$out/apphost-restore.log" 2>&1; then
  pass "apphost restore succeeds"
  ah_downloads "$apphost_fixture/AppHost.Tests/obj/project.assets.json" > "$out/apphost-downloads.txt"
  for tfm in net8.0 net9.0 net10.0; do
    grep -qx "$tfm $ah_host" "$out/apphost-downloads.txt" \
      && pass "apphost restore downloads $ah_host for $tfm" \
      || bad "apphost restore does not download $ah_host for $tfm (see $out/apphost-downloads.txt)"
  done
else
  bad "apphost restore (see $out/apphost-restore.log)"; tail -n 20 "$out/apphost-restore.log"
fi

if $clean_env dotnet build "$ah_proj" -c Release -nologo --no-restore $ah_props > "$out/apphost-build.log" 2>&1; then
  pass "apphost a net8.0;net9.0;net10.0 xunit.v3 test project builds"
  for tfm in net8.0 net9.0 net10.0; do
    ls "$apphost_fixture/AppHost.Tests/obj/Release/$tfm"/apphost* > /dev/null 2>&1 \
      && pass "apphost $tfm has an apphost" || bad "apphost $tfm has no apphost in obj/Release/$tfm"
  done
else
  bad "apphost build (see $out/apphost-build.log)"; grep -m 5 "error" "$out/apphost-build.log"
fi

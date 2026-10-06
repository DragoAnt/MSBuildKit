#!/bin/sh
# Kit packages: every kit.parts row has a pack project under kit/packages, every package carries the
# mskit.package.json marker and its part's msbuild files, DragoAnt.MSBuildKit.Defaults pins the default
# parts, and no package carries the owner layer. Leaves the folder feed in <out>/feed.
# Restores into folders of its own (tests/nuget-isolation.sh).
# Usage: sh tests/kit-packages.sh [--version <version>] [--out <dir>] [--no-nuget-fallback]
set -eu

here=$(cd "$(dirname "$0")/.." && pwd)
version="0.0.0-local.$(date +%s)"
out="$here/dist/kit-packages"
fallback=fallback
while [ $# -gt 0 ]; do
  case "$1" in
    --version) version="$2"; shift 2 ;;
    --out) mkdir -p "$2"; out=$(cd "$2" && pwd); shift 2 ;;
    --no-nuget-fallback) fallback=no-fallback; shift ;;
    *) echo "usage: sh tests/kit-packages.sh [--version <version>] [--out <dir>] [--no-nuget-fallback]" >&2; exit 1 ;;
  esac
done
rm -rf "$out"; mkdir -p "$out"
command -v unzip > /dev/null 2>&1 || { echo "kit-packages: unzip is required"; exit 1; }

failures=0
pass() { echo "PASS  $*"; }
bad() { echo "FAIL  $*"; failures=$((failures+1)); }

. "$here/tests/nuget-isolation.sh"
ni_begin kit-packages "$fallback"

kit="$here/kit"
msb="$kit/.toolkit/msbuild"
pk="$kit/packages"
feed="$out/feed"
defaults=DragoAnt.MSBuildKit.Defaults
clean_env="env -u GITHUB_ACTIONS -u GITHUB_RUN_ID -u GITHUB_RUN_NUMBER -u GITHUB_REF -u GITHUB_REF_NAME -u GITHUB_REF_TYPE -u GITHUB_EVENT_NAME -u GITHUB_HEAD_REF -u GITHUB_SHA -u GITHUB_REPOSITORY"

part_id() { if [ "$1" = Trunk ]; then echo DragoAnt.MSBuildKit; else echo "DragoAnt.MSBuildKit.$1"; fi; }
xprop() { tr -d '\r' < "$1" | sed -n "s:.*<$2>\(.*\)</$2>.*:\1:p" | head -n 1; }
xrefs() { tr -d '\r' < "$1" | sed -n 's:.*<ProjectReference Include="\([^"]*\)".*:\1:p' | sed 's:.*[/\\]::; s:\.csproj$::' | LC_ALL=C sort; }
words() { for w in "$@"; do echo "$w"; done | LC_ALL=C sort; }

# Writes the isolating Directory.* files of a test-time project folder; kit=yes imports the working-tree kit.
scaffold_dir() {
  mkdir -p "$1"
  if [ "$2" = kit ]; then
    printf '<Project>\n  <Import Project="%s/init.props" />\n</Project>\n' "$(ni_native "$msb")" > "$1/Directory.Build.props"
    printf '<Project>\n  <Import Project="%s/init.targets" />\n</Project>\n' "$(ni_native "$msb")" > "$1/Directory.Build.targets"
  else
    printf '<Project />\n' > "$1/Directory.Build.props"; printf '<Project />\n' > "$1/Directory.Build.targets"
  fi
  printf '<Project>\n  <PropertyGroup>\n    <ManagePackageVersionsCentrally>false</ManagePackageVersionsCentrally>\n  </PropertyGroup>\n</Project>\n' > "$1/Directory.Packages.props"
}

# 1. Consistency, pure sh.
grep -v '^#' "$kit/.toolkit/kit.parts" | tr -d '\r' | awk 'NF' > "$out/rows"
: > "$out/ids"; : > "$out/default-ids"
consistent=0
while read -r part kind requires; do
  id=$(part_id "$part"); echo "$id" >> "$out/ids"
  [ "$kind" = default ] && echo "$id" >> "$out/default-ids"
  proj="$pk/$id/$id.csproj"
  if [ ! -f "$proj" ]; then bad "consistency: kit.parts row $part has no project $proj"; consistent=1; continue; fi
  [ "$(xprop "$proj" PackageId)" = "$id" ] || { bad "consistency: $proj has PackageId '$(xprop "$proj" PackageId)', expected $id"; consistent=1; }
  expected=""; [ "$id" = DragoAnt.MSBuildKit.Core ] || expected="DragoAnt.MSBuildKit.Core"
  for r in $requires; do expected="$expected $(part_id "$r")"; done
  # shellcheck disable=SC2086
  if [ "$(words $expected)" != "$(xrefs "$proj")" ]; then
    bad "consistency: $id references '$(xrefs "$proj" | tr '\n' ' ')', expected Core plus the row's requires '$expected'"; consistent=1
  fi
  dir=$(xprop "$proj" MSKit_KitPackageMsbuildDir | sed "s:\$(PackageId):$id:")
  if [ -z "$dir" ] || [ ! -d "$pk/$id/$dir" ]; then bad "consistency: $id has MSKit_KitPackageMsbuildDir '$dir', not a folder"; consistent=1; fi
  case "$(xprop "$proj" MSKit_KitPackageOrder)" in
    ''|*[!0-9]*) bad "consistency: $id sets no numeric MSKit_KitPackageOrder"; consistent=1 ;;
  esac
done < "$out/rows"
for d in "$pk"/*/; do
  name=$(basename "$d")
  [ "$name" = "$defaults" ] && continue
  grep -qxF "$name" "$out/ids" || { bad "consistency: kit/packages/$name has no kit.parts row"; consistent=1; }
done
dproj="$pk/$defaults/$defaults.csproj"
if [ -f "$dproj" ]; then
  [ "$(xrefs "$dproj")" = "$(LC_ALL=C sort "$out/default-ids")" ] || { bad "consistency: $defaults references '$(xrefs "$dproj" | tr '\n' ' ')', expected every default row"; consistent=1; }
  [ "$(xprop "$dproj" MSKit_KitPackageUmbrella)" = true ] || { bad "consistency: $defaults does not set MSKit_KitPackageUmbrella=true"; consistent=1; }
else
  bad "consistency: no $dproj"; consistent=1
fi
# The order follows today's props order; parts with targets only, then parts new since, come after.
tr -d '\r' < "$msb/init.props" | sed -n 's:.*Import Project="\$(MSBuildThisFileDirectory)\([^/"]*\)/init\.props".*:\1:p' > "$out/props-order"
late="DragoAnt.MSBuildKit.Project.KitPackage"
{ grep -vxF "$late" "$out/props-order"
  while read -r id; do grep -qxF "$id" "$out/props-order" || echo "$id"; done < "$out/ids"
  echo "$late"; } | awk '!seen[$0]++' > "$out/order-sequence"
prev=-1; previd=""
while read -r id; do
  proj="$pk/$id/$id.csproj"; [ -f "$proj" ] || continue
  o=$(xprop "$proj" MSKit_KitPackageOrder)
  case "$o" in ''|*[!0-9]*) continue ;; esac
  if [ "$o" -le "$prev" ]; then bad "consistency: $id has order $o, not above $previd's $prev (the order of $msb/init.props)"; consistent=1; fi
  prev=$o; previd=$id
done < "$out/order-sequence"
[ "$consistent" -eq 0 ] && pass "consistency: $(grep -c . "$out/rows") kit.parts rows, one project each with Core and the row's requires, $defaults over the default rows, orders ascending in load order"

# 2. Pack.
if (cd "$pk" && $clean_env dotnet pack Packages.slnx -c Release -nologo -tl:off "-p:Version=$version" -p:TreatWarningsAsErrors=true -o "$feed") > "$out/pack.log" 2>&1; then
  pass "pack: Packages.slnx packs at $version with warnings as errors"
else
  bad "pack: Packages.slnx (see $out/pack.log)"; grep -E ': (error|warning) ' "$out/pack.log" | sort -u | head -n 20
fi
warnings=$(grep -E ': warning [A-Z]+[0-9]+' "$out/pack.log" | sort -u | grep -c . || true)
[ "$warnings" -eq 0 ] && pass "pack: 0 warnings" || bad "pack: $warnings warning(s) (see $out/pack.log)"
expected_count=$(( $(grep -c . "$out/ids") + 1 ))
packed=$(find "$feed" -name '*.nupkg' 2> /dev/null | grep -c . || true)
[ "$packed" -eq "$expected_count" ] && pass "pack: $packed packages, one per kit.parts row plus $defaults" || bad "pack: $packed packages, expected $expected_count"

# Every package unzipped, for the checks that read every package.
mkdir -p "$out/extract"
for f in "$feed"/*.nupkg; do
  [ -f "$f" ] || continue
  n=$(basename "$f" ".$version.nupkg"); mkdir -p "$out/extract/$n"; (cd "$out/extract/$n" && unzip -qo "$f")
done

# 3. Restore, not unzip.
scaf="$out/scaffold"
scaffold_dir "$scaf" plain
cat > "$scaf/Scaffold.csproj" << EOF
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>netstandard2.0</TargetFramework>
    <DisableImplicitFrameworkReferences>true</DisableImplicitFrameworkReferences>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="$defaults" Version="$version" />
    <PackageReference Include="DragoAnt.MSBuildKit.EF" Version="$version" />
  </ItemGroup>
</Project>
EOF
packages=$(ni_packages_dir)
if (cd "$scaf" && dotnet restore Scaffold.csproj -nologo --source "$(ni_native "$feed")") > "$out/restore.log" 2>&1; then
  pass "restore: a project referencing $defaults and DragoAnt.MSBuildKit.EF restores from the folder feed"
else
  bad "restore: the scaffold (see $out/restore.log)"; tail -n 10 "$out/restore.log"
fi
tr -d '\r' < "$scaf/obj/project.assets.json" 2> /dev/null > "$out/assets.json" || true
{ cat "$out/default-ids"; echo DragoAnt.MSBuildKit.EF; echo "$defaults"; } > "$out/restored-ids"
missing=""
while read -r id; do grep -qF "\"$id/$version\": {" "$out/assets.json" || missing="$missing $id"; done < "$out/restored-ids"
[ -z "$missing" ] && pass "restore: project.assets.json lists every default part, EF and $defaults (transitive parts included)" || bad "restore: project.assets.json lacks$missing"

problems=""
while read -r id; do
  lid=$(printf '%s' "$id" | tr '[:upper:]' '[:lower:]'); lv=$(printf '%s' "$version" | tr '[:upper:]' '[:lower:]')
  dir="$packages/$lid/$lv"
  [ -d "$dir" ] || { problems="$problems; $id not extracted to $dir"; continue; }
  marker="$dir/mskit.package.json"
  if [ ! -f "$marker" ]; then problems="$problems; $id has no mskit.package.json"; continue; fi
  tr -d '\r' < "$marker" > "$out/marker.tmp"
  grep -q "\"id\": \"$id\"" "$out/marker.tmp" || problems="$problems; $id marker id differs"
  if [ "$id" = "$defaults" ]; then
    grep -q '"umbrella": true' "$out/marker.tmp" || problems="$problems; $id marker is not an umbrella"
  else
    o=$(xprop "$pk/$id/$id.csproj" MSKit_KitPackageOrder)
    grep -q "\"order\": $o," "$out/marker.tmp" || problems="$problems; $id marker order is not $o"
    grep -q '"umbrella": false' "$out/marker.tmp" || problems="$problems; $id marker has no umbrella false"
    if ! diff -r "$msb/$id" "$dir/msbuild" > /dev/null 2>&1; then problems="$problems; $id msbuild/ differs from kit/.toolkit/msbuild/$id"; fi
  fi
done < "$out/restored-ids"
[ -z "$problems" ] && pass "restore: every restored package has its marker (id, order, umbrella) and msbuild/ equal to its part folder, byte for byte" || bad "restore:${problems#;}"

layout=""
for d in "$out/extract"/*/; do
  n=$(basename "$d")
  for sub in msbuild.init res lib; do [ ! -e "$d$sub" ] || layout="$layout $n/$sub"; done
  [ -f "$d/mskit.package.json" ] || layout="$layout $n:no-marker"
  if grep -qi 'developmentDependency' "$d"/*.nuspec 2> /dev/null; then layout="$layout $n:developmentDependency"; fi
done
[ -z "$layout" ] && pass "layout: no package has msbuild.init/, res/ or lib/, every package has a marker, no nuspec has developmentDependency" || bad "layout:$layout"

dnuspec="$out/extract/$defaults/$defaults.nuspec"
if [ -f "$dnuspec" ]; then
  tr -d '\r' < "$dnuspec" > "$out/defaults.nuspec"
  deps=""
  while read -r id; do grep -q "<dependency id=\"$id\" version=\"$version\"" "$out/defaults.nuspec" || deps="$deps $id"; done < "$out/default-ids"
  [ -z "$deps" ] && pass "defaults: the nuspec depends on every default part at $version" || bad "defaults: the nuspec lacks$deps"
  grep -q 'exclude=' "$out/defaults.nuspec" && bad "defaults: a dependency has an exclude attribute" || pass "defaults: no dependency excludes assets"
else
  bad "defaults: no $dnuspec"
fi

# 4. Owner guard, proven on a planted copy.
owner_grep() { grep -rlF -e '<ManufacturerName>DragoAnt' -e 'package.icon.png' -e '<MSKit_PrereleasePackagePrefix>DragoAnt.' "$1" 2> /dev/null || true; }
found=$(owner_grep "$out/extract")
[ -z "$found" ] && [ -d "$out/extract/$defaults" ] && pass "owner guard: no package carries an owner value" || bad "owner guard: $(echo $found)"
planted=0
for value in '<ManufacturerName>DragoAnt</ManufacturerName>' 'res/package.icon.png' '<MSKit_PrereleasePackagePrefix>DragoAnt.</MSKit_PrereleasePackagePrefix>'; do
  rm -rf "$out/planted"; mkdir -p "$out/planted"; cp -R "$out/extract/." "$out/planted/"
  printf '%s\n' "$value" >> "$out/planted/DragoAnt.MSBuildKit.Core/msbuild/init.props"
  [ -n "$(owner_grep "$out/planted")" ] && planted=$((planted+1))
done
rm -rf "$out/planted"
[ "$planted" -eq 3 ] && pass "owner guard: the grep finds each of the three values planted in a copy" || bad "owner guard: the grep found $planted of 3 planted values"

# 5. dotnet pack --no-build still carries the marker.
nb="$out/nobuild"
core="$pk/DragoAnt.MSBuildKit.Core/DragoAnt.MSBuildKit.Core.csproj"
if $clean_env dotnet build "$core" -c Release -nologo -tl:off "-p:Version=$version-nobuild" > "$out/nobuild-build.log" 2>&1 \
  && $clean_env dotnet pack "$core" -c Release -nologo -tl:off --no-build "-p:Version=$version-nobuild" -o "$nb/feed" > "$out/nobuild-pack.log" 2>&1; then
  scaffold_dir "$nb/scaffold" plain
  printf '<Project Sdk="Microsoft.NET.Sdk">\n  <PropertyGroup>\n    <TargetFramework>netstandard2.0</TargetFramework>\n    <DisableImplicitFrameworkReferences>true</DisableImplicitFrameworkReferences>\n  </PropertyGroup>\n  <ItemGroup>\n    <PackageReference Include="DragoAnt.MSBuildKit.Core" Version="%s" />\n  </ItemGroup>\n</Project>\n' "$version-nobuild" > "$nb/scaffold/Scaffold.csproj"
  (cd "$nb/scaffold" && dotnet restore Scaffold.csproj -nologo --source "$(ni_native "$nb/feed")") > "$out/nobuild-restore.log" 2>&1 || true
  lv=$(printf '%s' "$version-nobuild" | tr '[:upper:]' '[:lower:]')
  [ -f "$packages/dragoant.msbuildkit.core/$lv/mskit.package.json" ] && pass "--no-build: the restored package still has mskit.package.json" \
    || bad "--no-build: the restored package has no marker (see $out/nobuild-pack.log, $out/nobuild-restore.log)"
else
  bad "--no-build: build or pack failed (see $out/nobuild-build.log, $out/nobuild-pack.log)"
fi

# 6. The umbrella shape: PrivateAssets="none" writes the dependency, "all" drops it.
um="$out/umbrella"
scaffold_dir "$um" kit
mkdir -p "$um/DragoAnt.Fixture.Umbrella"
cat > "$um/DragoAnt.Fixture.Umbrella/DragoAnt.Fixture.Umbrella.csproj" << EOF
<Project Sdk="Microsoft.NET.Sdk">
  <Import Project="\$(KitPackageCommonPropsPath)" />
  <PropertyGroup>
    <PackageId>DragoAnt.Fixture.Umbrella</PackageId>
    <Description>A fixture umbrella that pins one kit part.</Description>
    <MSKit_KitPackageUmbrella>true</MSKit_KitPackageUmbrella>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="DragoAnt.MSBuildKit.Testing" Version="$version" PrivateAssets="\$(UmbrellaPrivateAssets)" />
  </ItemGroup>
</Project>
EOF
for assets in none all; do
  if $clean_env dotnet pack "$um/DragoAnt.Fixture.Umbrella/DragoAnt.Fixture.Umbrella.csproj" -c Release -nologo -tl:off "-p:Version=1.0.0-$assets" \
      "-p:UmbrellaPrivateAssets=$assets" -p:MSKit_SkipPackageChecks=All "-p:RestoreAdditionalProjectSources=$(ni_native "$feed")" \
      -o "$um/feed-$assets" > "$out/umbrella-$assets.log" 2>&1; then
    unzip -p "$um/feed-$assets/DragoAnt.Fixture.Umbrella.1.0.0-$assets.nupkg" DragoAnt.Fixture.Umbrella.nuspec | tr -d '\r' > "$out/umbrella-$assets.nuspec"
    unzip -p "$um/feed-$assets/DragoAnt.Fixture.Umbrella.1.0.0-$assets.nupkg" mskit.package.json | tr -d '\r' > "$out/umbrella-$assets.marker" || true
  else
    bad "umbrella: PrivateAssets=$assets did not pack (see $out/umbrella-$assets.log)"; grep -E ': error ' "$out/umbrella-$assets.log" | sort -u | head -n 5
  fi
done
grep -q "<dependency id=\"DragoAnt.MSBuildKit.Testing\" version=\"$version\"" "$out/umbrella-none.nuspec" 2> /dev/null \
  && ! grep -q 'exclude=' "$out/umbrella-none.nuspec" && grep -q '"umbrella": true' "$out/umbrella-none.marker" \
  && pass "umbrella: PrivateAssets=\"none\" packs the pinned part as a dependency with no exclude, marked umbrella" \
  || bad "umbrella: PrivateAssets=\"none\" did not pack the dependency (see $out/umbrella-none.nuspec)"
[ -f "$out/umbrella-all.nuspec" ] && ! grep -q '<dependency ' "$out/umbrella-all.nuspec" \
  && pass "umbrella: PrivateAssets=\"all\" packs no dependency, so the umbrella pins nothing" \
  || bad "umbrella: PrivateAssets=\"all\" still packs a dependency, or did not pack (see $out/umbrella-all.nuspec)"

# 7. Errors.
er="$out/errors"
scaffold_dir "$er" kit
error_case() {
  name="$1"; code="$2"; id="$3"; content="$4"
  mkdir -p "$er/$name"
  [ -z "$content" ] || { mkdir -p "$er/$name/$(dirname "$content")"; printf '<Project />\n' > "$er/$name/$content"; }
  printf '<Project Sdk="Microsoft.NET.Sdk">\n  <Import Project="$(KitPackageCommonPropsPath)" />\n  <PropertyGroup>\n    <PackageId>%s</PackageId>\n    <Description>A fixture kit package that the kit must refuse.</Description>\n  </PropertyGroup>\n</Project>\n' "$id" > "$er/$name/$name.csproj"
  if $clean_env dotnet pack "$er/$name/$name.csproj" -c Release -nologo -tl:off -p:Version=1.0.0 -p:MSKit_SkipPackageChecks=All -o "$er/feed" > "$out/error-$name.log" 2>&1; then
    bad "errors: $name packed; expected $code"
  elif grep -q "error $code" "$out/error-$name.log"; then
    pass "errors: $name fails with $code"
  else
    bad "errors: $name failed without $code (see $out/error-$name.log)"; grep -E ': error ' "$out/error-$name.log" | sort -u | head -n 3
  fi
}
error_case BadId MSKITKPKG001 "Bad Id" msbuild/init.props
error_case OtherInit MSKITKPKG002 DragoAnt.Fixture.OtherInit msbuild.init/other.props
error_case Empty MSKITKPKG003 DragoAnt.Fixture.Empty ""

# 8. The zip still ships the owner layer and the new part.
if sh "$here/tools/pack-kit.sh" "$version" "$out/zip" > "$out/zip.log" 2>&1; then
  unzip -l "$out/zip/msbuildkit-$version.zip" | awk 'NR>3 {print $4}' | tr '\\' '/' > "$out/zip.files"
  zipmiss=""
  for f in .toolkit/msbuild/init.company.props .toolkit/res/package.icon.png .toolkit/msbuild/DragoAnt.MSBuildKit.Project.KitPackage/kit.package.props; do
    grep -qxF "$f" "$out/zip.files" || zipmiss="$zipmiss $f"
  done
  [ -z "$zipmiss" ] && pass "zip: still ships init.company.props, res/package.icon.png and Project.KitPackage" || bad "zip: lacks$zipmiss"
else
  bad "zip: tools/pack-kit.sh failed (see $out/zip.log)"
fi

ni_verify "$out" "$feed" "$nb" "$um" "$er"

echo
if [ "$failures" -eq 0 ]; then echo "kit-packages: all checks passed"; else echo "kit-packages: $failures failure(s)"; exit 1; fi

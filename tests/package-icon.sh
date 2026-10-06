# Package icon: packed under icon<extension, lowercased>, and a project's own PackageIcon is kept.
# Sourced by tests/run.sh: uses its pass, bad, $out, $here, $clean_env and $icon_fixture.

rm -rf "$icon_fixture"/*/bin "$icon_fixture"/*/obj

ic_pack() {
  name="$1"; proj="$2"; shift 2
  rm -rf "$out/icon-$name"
  : > "$out/icon-$name.nuspec"; : > "$out/icon-$name.files"
  if $clean_env dotnet pack "$icon_fixture/$proj/$proj.csproj" -c Release -nologo -o "$out/icon-$name" \
      -p:MSKit_PackageChecksAsErrors=False "$@" > "$out/icon-$name.log" 2>&1; then
    pass "icon $name: pack succeeds"
    nupkg=$(ls "$out/icon-$name"/*.nupkg | grep -v '\.snupkg$' | head -n 1)
    unzip -p "$nupkg" '*.nuspec' | tr -d '\r' > "$out/icon-$name.nuspec"
    unzip -l "$nupkg" | awk 'NR>3 {print $4}' | grep -v '^$' > "$out/icon-$name.files"
  else
    bad "icon $name: pack failed (see $out/icon-$name.log)"; tail -n 20 "$out/icon-$name.log"
  fi
}
ic_icon() {
  actual=$(sed -n 's:.*<icon>\(.*\)</icon>.*:\1:p' "$out/icon-$1.nuspec")
  [ "$actual" = "$2" ] && pass "icon $1: nuspec <icon>$actual</icon>" || bad "icon $1: nuspec <icon> expected '$2', got '$actual'"
}
ic_entry() { grep -qx -- "$2" "$out/icon-$1.files" && pass "icon $1: nupkg contains $2" || bad "icon $1: nupkg lacks $2"; }
ic_no_entry() { grep -qx -- "$2" "$out/icon-$1.files" && bad "icon $1: nupkg still contains $2" || pass "icon $1: nupkg has no $2"; }
ic_warns() { grep -q "warning $2" "$out/icon-$1.log" && pass "icon $1 warns $2" || bad "icon $1 does not warn $2 (see $out/icon-$1.log)"; }
ic_quiet() { grep -q "$2" "$out/icon-$1.log" && bad "icon $1 reports $2 (see $out/icon-$1.log)" || pass "icon $1 does not report $2"; }

# The kit's PNG icon.
ic_pack default Icons
ic_icon default icon.png
ic_entry default icon.png
ic_quiet default MSKIT_PKG015

# A JPEG PackageIconPath keeps its extension.
ic_pack jpg Icons -p:FixtureIcon=icon.jpg
ic_icon jpg icon.jpg
ic_entry jpg icon.jpg
ic_no_entry jpg icon.png
ic_quiet jpg NU5046
ic_quiet jpg MSKIT_PKG015

# A JPEG of the wrong size is still reported.
ic_pack jpg-small Icons -p:FixtureIcon=small.jpg
ic_icon jpg-small icon.jpg
ic_warns jpg-small MSKIT_PKG015

# An upper-case extension is lowercased.
ic_pack upper Icons -p:FixtureIcon=ICON.PNG
ic_icon upper icon.png
ic_entry upper icon.png
ic_no_entry upper ICON.PNG
ic_no_entry upper icon.PNG

# A project that sets PackageIcon keeps it; the kit's icon is not added.
ic_pack own Own
ic_icon own logo.png
ic_entry own logo.png
ic_no_entry own icon.png
ic_quiet own MSKIT_PKG015

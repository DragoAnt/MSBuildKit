# Codes: every code is spelled MSKIT<FAMILY><nnn>, and every diagnostic links to its section of
# docs/reference/codes.md through MSKit_CodesHelpBaseUrl. The terminal logger prints the HelpLink as
# an OSC 8 hyperlink on the code, which is how the link is read back here.
# Sourced by tests/run.sh: uses its pass, bad, $out, $here, $kit, $sample, $lib, $fixtures, $clean_env and $ci_env.

if grep -rn 'MSKIT[_]' "$here/kit" > "$out/codes-old-spelling.log"; then
  bad "codes: the kit spells a code with an underscore (see $out/codes-old-spelling.log)"; head -n 5 "$out/codes-old-spelling.log"
else
  pass "codes: no code in the kit is spelled with an underscore"
fi

codes_url="https://github.com/DragoAnt/MSBuildKit/blob/main/docs/reference/codes.md"
$clean_env $ci_env GITHUB_EVENT_NAME=release GITHUB_REF_TYPE=tag GITHUB_REF_NAME=release-x GITHUB_REF=refs/tags/release-x \
  dotnet restore "$lib" -nologo -tl:on > "$out/codes-helplink-ver006.log" 2>&1 || true
grep -qF "]8;;$codes_url#mskitver006" "$out/codes-helplink-ver006.log" \
  && pass "codes: MSKITVER006 links to $codes_url#mskitver006" || bad "codes: MSKITVER006 has no HelpLink to its section (see $out/codes-helplink-ver006.log)"

$clean_env dotnet pack "$fixtures/BadPackage/BadPackage.csproj" -c Release -nologo -tl:on -o "$out/codes-helplink-pkg" \
  -p:MSKit_PackageChecksAsErrors=False -p:MSKit_CodesHelpBaseUrl=https://codes.example/kit.md > "$out/codes-helplink-pkg.log" 2>&1 || true
for code in mskitpkg001 mskitpkg010; do
  grep -qF "]8;;https://codes.example/kit.md#$code" "$out/codes-helplink-pkg.log" \
    && pass "codes: MSKit_CodesHelpBaseUrl moves the $code link" || bad "codes: the $code link ignores MSKit_CodesHelpBaseUrl (see $out/codes-helplink-pkg.log)"
done

# The diagnostic catalog: every BuildDiagnosticDescriptor item reaches an evaluated project, defined
# by the file of the part that reports the code (a collector reads DefiningProjectFullPath).
catalog_items() {
  proj="$1"; name="$2"; shift 2
  $clean_env dotnet msbuild "$proj" -nologo -getItem:BuildDiagnosticDescriptor "$@" 2> "$out/$name.err" | tr -d '\r' > "$out/$name.json" || true
  awk '
    function val(l) { sub(/^[^:]*:[[:space:]]*"/, "", l); sub(/",?[[:space:]]*$/, "", l); gsub(/\\/, "/", l); return l }
    /^[[:space:]]*"Identity":/ { id = val($0) }
    /^[[:space:]]*"Title":/ { title = val($0) }
    /^[[:space:]]*"DefaultSeverity":/ { severity = val($0) }
    /^[[:space:]]*"HelpLink":/ { link = val($0) }
    /^[[:space:]]*"DefiningProjectFullPath":/ { part = val($0); if (!sub(/^.*\/\.toolkit\/msbuild\//, "", part) || !sub(/\/diagnostic\.descriptors\.props$/, "", part)) part = "?" }
    /^[[:space:]]*}/ { if (id != "") print id "\t" part "\t" severity "\t" link "\t" (title == "" ? "-" : "titled"); id = part = severity = link = title = "" }
  ' "$out/$name.json" | sort > "$out/$name.tsv"
}
sh "$here/tools/docs-check.sh" --list descriptors > "$out/catalog-declared.tsv" 2> "$out/catalog-declared.err" || true

catalog_root="$out/catalog"
rm -rf "$catalog_root"; mkdir -p "$catalog_root/App"
printf '<Project Sdk="Microsoft.NET.Sdk">\n  <PropertyGroup>\n    <TargetFramework>net8.0</TargetFramework>\n  </PropertyGroup>\n</Project>\n' > "$catalog_root/App/App.csproj"
sh "$kit/.toolkit/update.sh" --source "$kit" --root "$catalog_root" --add PackageAsProj > "$out/catalog-install.log" 2>&1 || { bad "catalog: update.sh --add PackageAsProj failed (see $out/catalog-install.log)"; tail -n 5 "$out/catalog-install.log"; }

catalog_items "$catalog_root/App/App.csproj" catalog-all
cut -f1,2 "$out/catalog-declared.tsv" > "$out/catalog-all.expected"
cut -f1,2 "$out/catalog-all.tsv" > "$out/catalog-all.actual"
catalog_count=$(grep -c . "$out/catalog-all.actual" || true)
[ "$catalog_count" -gt 0 ] && cmp -s "$out/catalog-all.expected" "$out/catalog-all.actual" \
  && pass "catalog: $catalog_count descriptors reach an evaluated project, each defined by the part that reports its code" \
  || { bad "catalog: the evaluated BuildDiagnosticDescriptor items differ from the kit's (diff $out/catalog-all.expected $out/catalog-all.actual)"; diff "$out/catalog-all.expected" "$out/catalog-all.actual" | head -n 10; }
grep -q "	DragoAnt.MSBuildKit.PackageAsProj$" "$out/catalog-all.actual" && pass "catalog: an optional part brings its descriptors when it is installed" || bad "catalog: no descriptor is defined by the PackageAsProj part (see $out/catalog-all.tsv)"
catalog_incomplete=$(awk -F'\t' '($3 != "Warning" && $3 != "Error") || $5 != "titled"' "$out/catalog-all.tsv" | grep -c . || true)
[ "$catalog_count" -gt 0 ] && [ "$catalog_incomplete" -eq 0 ] && pass "catalog: every evaluated descriptor has a Title and a DefaultSeverity of Warning or Error" \
  || bad "catalog: $catalog_incomplete of $catalog_count evaluated descriptor(s) lack a Title or a Warning/Error DefaultSeverity (see $out/catalog-all.tsv)"
grep -q "^MSKITVER006	DragoAnt.MSBuildKit	Error	$codes_url#mskitver006	" "$out/catalog-all.tsv" \
  && pass "catalog: MSKITVER006 evaluates to an Error linked to $codes_url#mskitver006" || bad "catalog: MSKITVER006 is not an Error linked to its section (see $out/catalog-all.tsv)"

catalog_items "$lib" catalog-sample
while IFS='	' read -r code part where; do
  [ -d "$sample/.toolkit/msbuild/$part" ] && printf '%s\t%s\n' "$code" "$part"
done < "$out/catalog-declared.tsv" > "$out/catalog-sample.expected"
cut -f1,2 "$out/catalog-sample.tsv" > "$out/catalog-sample.actual"
[ -s "$out/catalog-sample.actual" ] && cmp -s "$out/catalog-sample.expected" "$out/catalog-sample.actual" && ! grep -q "PackageAsProj" "$out/catalog-sample.actual" \
  && pass "catalog: the sample sees the $(grep -c . "$out/catalog-sample.actual") descriptors of its installed parts and none of a part it lacks" \
  || bad "catalog: the sample's descriptors are not those of its installed parts (diff $out/catalog-sample.expected $out/catalog-sample.actual)"

catalog_items "$lib" catalog-moved -p:MSKit_CodesHelpBaseUrl=https://codes.example/kit.md
grep -q "^MSKITPKG001	DragoAnt.MSBuildKit.Packaging	Warning	https://codes.example/kit.md#mskitpkg001	" "$out/catalog-moved.tsv" \
  && pass "catalog: MSKit_CodesHelpBaseUrl moves a descriptor's HelpLink" || bad "catalog: the MSKITPKG001 descriptor ignores MSKit_CodesHelpBaseUrl (see $out/catalog-moved.tsv)"

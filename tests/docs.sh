# Docs: the reference pages cover the kit, and tools/docs-check.sh catches what they miss.
# Sourced by tests/run.sh: uses its pass, bad, $out and $here.

dc_log="$out/docs-check.log"
if sh "$here/tools/docs-check.sh" > "$dc_log" 2>&1; then pass "docs: $(tail -n 1 "$dc_log" | sed 's/^docs-check: //')"
else bad "docs: tools/docs-check.sh found problems (see $dc_log)"; cat "$dc_log"; fi

# A copy with one property row, one code section, one name, one link, one anchor, two HelpLinks and
# the old code spelling in four places broken must fail on each.
dc_copy() {
  rm -rf "$1"; mkdir -p "$1/kit/.toolkit" "$1/samples/MinimalLibrary"
  cp -R "$here/kit/.toolkit/msbuild" "$1/kit/.toolkit/msbuild"
  cp -R "$here/docs" "$1/docs"
  for f in README.md CONTRIBUTING.md SECURITY.md CHANGELOG.md LICENSE; do cp "$here/$f" "$1/$f"; done
  mkdir -p "$1/tools"; cp "$here/tools/docs-check.sh" "$1/tools/docs-check.sh"
}
u=_
dc_bad="$out/docs-check-broken"
dc_copy "$dc_bad"
dc_kit="$dc_bad/kit/.toolkit/msbuild/DragoAnt.MSBuildKit/audit"
grep -v '^| `MSKit_SemVerRegex` |' "$here/docs/reference/properties.md" > "$dc_bad/docs/reference/properties.md"
sed "s/^### MSKITVER004\$/### Gone/; s/^### MSKITPAP002\$/### MSKIT${u}PAP002/" "$here/docs/reference/codes.md" > "$dc_bad/docs/reference/codes.md"
printf '\nSee `MSKit_NoSuchProperty`, `MSKITVER099`, formerly `MSKIT%sVER006`, [gone](./no-such-page.md), [anchor](./build.md#no-such-heading) and [bare](build.md).\n' "$u" >> "$dc_bad/docs/troubleshooting.md"
sed "s/^## \[Unreleased\]\$/&\n\n- The MSKIT${u}PKG checks./" "$here/CHANGELOG.md" > "$dc_bad/CHANGELOG.md"
sed 's/ HelpLink="$(MSKit_CodesHelpBaseUrl)#mskitver006"//; s/#mskitver007"/#mskitver001"/' "$here/kit/.toolkit/msbuild/DragoAnt.MSBuildKit/audit/audit.version.targets" > "$dc_kit/audit.version.targets"
sed "s/Code=\"MSKITRES002\"/Code=\"MSKIT${u}RES002\"/" "$here/kit/.toolkit/msbuild/DragoAnt.MSBuildKit/audit/audit.restrict.packages.targets" > "$dc_kit/audit.restrict.packages.targets"
sh "$dc_bad/tools/docs-check.sh" > "$out/docs-check-broken.log" 2>&1 && bad "docs: the check passed a broken copy (see $out/docs-check-broken.log)"
for needle in "property MSKit_SemVerRegex" "code MSKITVER004" "write the heading as MSKITPAP002" "mentions MSKit_NoSuchProperty" \
    "mentions MSKITVER099" "no-such-page.md points at a missing file" "no-such-heading names a heading" "build.md must start with ./" \
    "MSKITVER006 has no HelpLink" "MSKITVER007 has HelpLink=" "HelpLink anchor #mskitver004 has no heading" \
    "docs/troubleshooting.md:|old spelling of MSKITVER006" "CHANGELOG.md:|old spelling of MSKITPKG" \
    "audit.restrict.packages.targets:|old spelling of MSKITRES002" "docs/reference/codes.md:|old spelling of MSKITPAP002"; do
  where=${needle%%|*}; what=${needle#*|}
  grep -F "$where" "$out/docs-check-broken.log" | grep -qF "$what" && pass "docs: the check reports '$needle'" || bad "docs: the check missed '$needle' (see $out/docs-check-broken.log)"
done

# The diagnostic catalog: a copy with one descriptor missing, doubled, orphaned, in the wrong part,
# in the wrong file and unimported, and with each piece of metadata wrong, must fail on each.
dc_cat="$out/docs-check-catalog"
dc_copy "$dc_cat"
dc_parts="$dc_cat/kit/.toolkit/msbuild"
dc_item() { sed "/Include=\"$2\"/,/\/>/ $3" "$dc_parts/$1/diagnostic.descriptors.props" > "$dc_cat/item.tmp" && mv "$dc_cat/item.tmp" "$dc_parts/$1/diagnostic.descriptors.props"; }
dc_fake() { printf '    <BuildDiagnosticDescriptor Include="%s" Title="Fake" MessageFormat="Fake." Description="Fake." Category="Versioning" DefaultSeverity="Error" HelpLink="$(MSKit_CodesHelpBaseUrl)#%s" />' "$1" "$2"; }
if [ -f "$dc_parts/DragoAnt.MSBuildKit/diagnostic.descriptors.props" ]; then
  dc_item DragoAnt.MSBuildKit.Testing MSKITTEST031 d
  dc_item DragoAnt.MSBuildKit.Packaging MSKITPKG019 d
  dc_item DragoAnt.MSBuildKit.Testing.XUnit.v3 MSKITTEST005 d
  sed "s|^</Project>|  <ItemGroup>\n$(dc_fake MSKITVER003 mskitver003)\n$(dc_fake MSKITVER007 mskitver007)\n$(dc_fake MSKITTEST005 mskittest005)\n  </ItemGroup>\n&|" \
    "$here/kit/.toolkit/msbuild/DragoAnt.MSBuildKit/diagnostic.descriptors.props" > "$dc_parts/DragoAnt.MSBuildKit/diagnostic.descriptors.props"
  sed "s|^</Project>|  <ItemGroup>\n$(dc_fake MSKITVER098 mskitver098)\n  </ItemGroup>\n&|" \
    "$here/kit/.toolkit/msbuild/DragoAnt.MSBuildKit/audit/audit.version.targets" > "$dc_parts/DragoAnt.MSBuildKit/audit/audit.version.targets"
  grep -v 'diagnostic.descriptors.props' "$here/kit/.toolkit/msbuild/DragoAnt.MSBuildKit.Core/init.props" > "$dc_parts/DragoAnt.MSBuildKit.Core/init.props"
  grep -v 'DragoAnt.MSBuildKit.PackageAsProj/init.props' "$here/kit/.toolkit/msbuild/init.props" > "$dc_parts/init.props"
  dc_item DragoAnt.MSBuildKit.Core MSKITCORE001 's/#mskitcore001"/#mskitroslyn001"/'
  dc_item DragoAnt.MSBuildKit.Core MSKITROSLYN001 's/DefaultSeverity="Error"/DefaultSeverity="Warning"/'
  dc_item DragoAnt.MSBuildKit.Core MSKITROSLYN002 's/DefaultSeverity="Error"/DefaultSeverity="Info"/'
  dc_item DragoAnt.MSBuildKit MSKITPRE001 's/DefaultSeverity="Warning"/DefaultSeverity="Error"/'
  dc_item DragoAnt.MSBuildKit MSKITRES001 's/Category="[^"]*"/Category="Versioning"/'
  dc_item DragoAnt.MSBuildKit MSKITDUP001 's/Description="/Description="In short: /'
  dc_item DragoAnt.MSBuildKit MSKITVER004 's/MessageFormat="/MessageFormat="Oops. /'
  dc_item DragoAnt.MSBuildKit.Packaging MSKITPKG004 's/MessageFormat="/MessageFormat="Oops. /'
  dc_item DragoAnt.MSBuildKit.Packaging MSKITPKG003 's/ Title="[^"]*"/ Title=""/'
  dc_item DragoAnt.MSBuildKit.PackageAsProj MSKITPAP002 's/Title="/Title="Not /'
  dc_item DragoAnt.MSBuildKit.Testing MSKITTEST010 's/%24(/$(/'
fi
sh "$dc_cat/tools/docs-check.sh" > "$out/docs-check-catalog.log" 2>&1 && bad "docs: the check passed a broken catalog (see $out/docs-check-catalog.log)"
for needle in "code MSKITTEST031 (|has no BuildDiagnosticDescriptor item; add one to kit/.toolkit/msbuild/DragoAnt.MSBuildKit.Testing/diagnostic.descriptors.props" \
    "code MSKITPKG019 (|has no BuildDiagnosticDescriptor item" "MSKITVER007 already has a BuildDiagnosticDescriptor" \
    "MSKITVER003 has a BuildDiagnosticDescriptor, but no <Warning> or <Error> reports it" \
    "MSKITTEST005 is described in part DragoAnt.MSBuildKit, but reported by DragoAnt.MSBuildKit.Testing.XUnit.v3" \
    "audit.version.targets:|declare MSKITVER098 in its part folder, in diagnostic.descriptors.props" \
    "diagnostic.descriptors.props is not imported by kit/.toolkit/msbuild/DragoAnt.MSBuildKit.Core/init.props" \
    "does not import DragoAnt.MSBuildKit.PackageAsProj/init.props" \
    "MSKITCORE001 has HelpLink=" "MSKITROSLYN001 has DefaultSeverity=\"Warning\", but no <Warning> reports it" \
    "MSKITROSLYN002 has DefaultSeverity=\"Info\"; use Warning or Error" \
    "MSKITPRE001 has DefaultSeverity=\"Error\", but its section in docs/reference/codes.md says (warning)" \
    "MSKITRES001 has Category=\"Versioning\", but its section in docs/reference/codes.md is under \"References\"" \
    "the Description of MSKITDUP001 is not the opening sentence(s)" "the MessageFormat of MSKITVER004 is not the text its task reports" \
    "the MessageFormat of MSKITPKG004 is not the text its task reports" "MSKITPKG003 has no Title" "MSKITPAP002 has Title=\"Not " \
    "MSKITTEST010 has metadata MSBuild would expand"; do
  where=${needle%%|*}; what=${needle#*|}
  grep -F "$where" "$out/docs-check-catalog.log" | grep -qF "$what" && pass "docs: the check reports '$needle'" || bad "docs: the check missed '$needle' (see $out/docs-check-catalog.log)"
done

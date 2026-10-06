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

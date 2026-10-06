# Docs: the reference pages cover the kit, and tools/docs-check.sh catches what they miss.
# Sourced by tests/run.sh: uses its pass, bad, $out and $here.

dc_log="$out/docs-check.log"
if sh "$here/tools/docs-check.sh" > "$dc_log" 2>&1; then pass "docs: $(tail -n 1 "$dc_log" | sed 's/^docs-check: //')"
else bad "docs: tools/docs-check.sh found problems (see $dc_log)"; cat "$dc_log"; fi

# A copy with one property row, one code section, one name, one link and one anchor broken must fail on each.
dc_copy() {
  rm -rf "$1"; mkdir -p "$1/kit/.toolkit" "$1/samples/MinimalLibrary"
  cp -R "$here/kit/.toolkit/msbuild" "$1/kit/.toolkit/msbuild"
  cp -R "$here/docs" "$1/docs"
  for f in README.md CONTRIBUTING.md SECURITY.md CHANGELOG.md LICENSE; do cp "$here/$f" "$1/$f"; done
  mkdir -p "$1/tools"; cp "$here/tools/docs-check.sh" "$1/tools/docs-check.sh"
}
dc_bad="$out/docs-check-broken"
dc_copy "$dc_bad"
grep -v '^| `MSKit_SemVerRegex` |' "$here/docs/reference/properties.md" > "$dc_bad/docs/reference/properties.md"
sed 's/^### MSKITVER004$/### Gone/; s/^### MSKITPAP002$/### MSKIT_PAP002/' "$here/docs/reference/codes.md" > "$dc_bad/docs/reference/codes.md"
printf '\nSee `MSKit_NoSuchProperty`, `MSKIT_VER099`, [gone](./no-such-page.md), [anchor](./build.md#no-such-heading) and [bare](build.md).\n' >> "$dc_bad/docs/troubleshooting.md"
sh "$dc_bad/tools/docs-check.sh" > "$out/docs-check-broken.log" 2>&1 && bad "docs: the check passed a broken copy (see $out/docs-check-broken.log)"
for needle in "property MSKit_SemVerRegex" "code MSKITVER004" "write the heading as MSKITPAP002" "mentions MSKit_NoSuchProperty" \
    "mentions MSKITVER099" "no-such-page.md points at a missing file" "no-such-heading names a heading" "build.md must start with ./"; do
  grep -qF "$needle" "$out/docs-check-broken.log" && pass "docs: the check reports '$needle'" || bad "docs: the check missed '$needle' (see $out/docs-check-broken.log)"
done

# The planned code rename (MSKIT_VER006 -> MSKITVER006) must not break the check.
dc_renamed="$out/docs-check-renamed"
dc_copy "$dc_renamed"
sed 's/MSKIT_VER006/MSKITVER006/g' "$here/kit/.toolkit/msbuild/DragoAnt.MSBuildKit/audit/audit.version.targets" \
  > "$dc_renamed/kit/.toolkit/msbuild/DragoAnt.MSBuildKit/audit/audit.version.targets"
grep -q 'Code="MSKITVER006"' "$dc_renamed/kit/.toolkit/msbuild/DragoAnt.MSBuildKit/audit/audit.version.targets" || bad "docs: the rename fixture did not rename MSKIT_VER006"
sh "$dc_renamed/tools/docs-check.sh" > "$out/docs-check-renamed.log" 2>&1 \
  && pass "docs: a code spelled without the underscore still matches its section" || { bad "docs: the renamed code broke the check (see $out/docs-check-renamed.log)"; cat "$out/docs-check-renamed.log"; }

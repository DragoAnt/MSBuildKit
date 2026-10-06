# Codes: every code is spelled MSKIT<FAMILY><nnn>, and every diagnostic links to its section of
# docs/reference/codes.md through MSKit_CodesHelpBaseUrl. The terminal logger prints the HelpLink as
# an OSC 8 hyperlink on the code, which is how the link is read back here.
# Sourced by tests/run.sh: uses its pass, bad, $out, $here, $lib, $fixtures, $clean_env and $ci_env.

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

# update.sh / update.ps1 replace themselves during an update: the run that does it must still finish.
# Sourced by tests/run.sh: uses its pass, bad, $out and $kit.

us_consumer() {
  dir="$out/update-self/$1"
  rm -rf "$dir"; mkdir -p "$dir/.toolkit"
  printf '{\n  "repository": "DragoAnt/MSBuildKit",\n  "version": "0.0.1",\n  "sha256": "",\n  "parts": []\n}\n' > "$dir/.toolkit/kit.json"
}
# The installed copy differs in length from the new one, as an older release or a CRLF checkout does.
us_pad() {
  head -n 1 "$1"
  i=0; while [ $i -lt 80 ]; do echo "# padding that moves every later line of the installed copy away from the new one"; i=$((i+1)); done
  tail -n +2 "$1"
}
us_check() {
  name="$1"; log="$2"; status="$3"
  version=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$dir/.toolkit/kit.json")
  [ "$status" -eq 0 ] && [ "$version" = "9.9.9" ] && grep -q "done: DragoAnt.MSBuildKit 9.9.9" "$log" \
    && pass "update $name finishes in one run (kit.json 9.9.9)" \
    || { bad "update $name: exit $status, kit.json '$version' (see $log)"; tail -n 5 "$log"; }
  cmp -s "$dir/.toolkit/$4" "$kit/.toolkit/$4" && pass "update $name replaced $4" || bad "update $name left the old $4"
}

us_consumer sh-longer
us_pad "$kit/.toolkit/update.sh" > "$dir/.toolkit/update.sh"
status=0; (cd "$dir" && sh .toolkit/update.sh --source "$kit" --version 9.9.9) > "$dir.log" 2>&1 || status=$?
us_check sh-longer "$dir.log" "$status" update.sh

printf 'true\r\n' > "$out/update-self-cr.sh"
if sh "$out/update-self-cr.sh" > /dev/null 2>&1; then
  us_consumer sh-crlf
  sed 's/$/\r/' "$kit/.toolkit/update.sh" > "$dir/.toolkit/update.sh"
  status=0; (cd "$dir" && sh .toolkit/update.sh --source "$kit" --version 9.9.9) > "$dir.log" 2>&1 || status=$?
  us_check sh-crlf "$dir.log" "$status" update.sh
else
  pass "update sh-crlf skipped: this sh does not run CRLF scripts"
fi

if command -v pwsh > /dev/null 2>&1; then
  us_consumer ps1-longer
  us_pad "$kit/.toolkit/update.ps1" > "$dir/.toolkit/update.ps1"
  status=0; (cd "$dir" && pwsh -NoProfile -NonInteractive -File .toolkit/update.ps1 -Source "$kit" -Version 9.9.9) > "$dir.log" 2>&1 || status=$?
  us_check ps1-longer "$dir.log" "$status" update.ps1
else
  pass "update ps1-longer skipped: no pwsh"
fi

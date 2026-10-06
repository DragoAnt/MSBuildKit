# NuGet isolation: a run restores into a global-packages folder of its own, so a package built here
# never reaches the machine's one, where any other build on the machine would resolve it.
# Sourced by tests/run.sh and tests/manager.sh: uses their pass, bad and $here.

ni_fixture="$here/tests/fixtures/NuGetIsolation"
ni_probe_id=dragoant.fixture.cacheprobe

ni_native() { if command -v cygpath > /dev/null 2>&1; then cygpath -m "$1"; else printf '%s\n' "$1"; fi; }

# The global-packages folder NuGet uses under <dir> when no caller overrides it.
ni_machine_folder() {
  (cd "$1" && env -u NUGET_PACKAGES dotnet nuget locals global-packages --list) | tr -d '\r' \
    | sed -n 's/^global-packages: //p' | tr '\' '/' | sed 's:/*$::'
}

# ni_begin <packages-dir> <fallback|no-fallback>: fallback reads the machine's folder for what it
# already holds; nothing is written to a fallback folder.
ni_begin() {
  ni_machine=$(ni_machine_folder "$here")
  [ -n "$ni_machine" ] || { echo "nuget isolation: cannot find the machine's global-packages folder" >&2; exit 1; }
  ni_own=""
  if [ -n "${NUGET_PACKAGES:-}" ]; then
    echo "NOTE  NUGET_PACKAGES is set: restoring into $NUGET_PACKAGES"
    return 0
  fi
  ni_own="$1"
  rm -rf "$ni_own"; mkdir -p "$ni_own"
  NUGET_PACKAGES=$(ni_native "$ni_own"); export NUGET_PACKAGES
  if [ "$2" = fallback ] && [ -z "${NUGET_FALLBACK_PACKAGES:-}" ] && [ -d "$ni_machine" ]; then
    NUGET_FALLBACK_PACKAGES=$ni_machine; export NUGET_FALLBACK_PACKAGES
  fi
}

ni_end() { [ -z "${ni_own:-}" ] || rm -rf "$ni_own" || echo "NOTE  could not remove $ni_own"; }

# ni_leaks <global-packages-dir> <dir>...: prints "<id> <version>" for every package under the
# directories that the folder holds. Fails when the directories hold no package at all.
ni_leaks() {
  ni_dir="$1"; shift
  ni_list=$(mktemp)
  find "$@" -name '*.nupkg' 2> /dev/null | while IFS= read -r ni_file; do
    unzip -p "$ni_file" '*.nuspec' | tr -d '\r' | awk '
      match($0, /<id>[^<]*<\/id>/) && id == "" { id = substr($0, RSTART + 4, RLENGTH - 9) }
      match($0, /<version>[^<]*<\/version>/) && version == "" { version = substr($0, RSTART + 9, RLENGTH - 19) }
      END { sub(/\+.*/, "", version); print tolower(id), tolower(version) }'
  done | LC_ALL=C sort -u > "$ni_list"
  ni_found=0
  while read -r ni_id ni_version; do
    ni_found=1
    [ ! -d "$ni_dir/$ni_id/$ni_version" ] || echo "$ni_id $ni_version"
  done < "$ni_list"
  rm -f "$ni_list"
  [ "$ni_found" -eq 1 ]
}

# ni_restore_probe <work-dir> <feed> <version> [env...]: restores a consumer of the probe package.
ni_restore_probe() {
  ni_work="$1"; ni_feed="$2"; ni_version="$3"; shift 3
  mkdir -p "$ni_work"; cp -R "$ni_fixture/Consumer" "$ni_work/Consumer"
  (cd "$ni_work" && "$@" dotnet restore Consumer/Consumer.csproj -nologo --source "$(ni_native "$ni_feed")" "-p:ProbeVersion=$ni_version") > "$ni_work/restore.log" 2>&1
}

# ni_verify <out-dir> <dir>...: the checks. <dir>... hold the packages the run built.
ni_verify() {
  ni_out="$1/nuget-isolation"; shift
  rm -rf "$ni_out"; mkdir -p "$ni_out/src"
  ni_version="0.0.0-probe.$(date +%s).$$"
  cp -R "$ni_fixture/Probe" "$ni_out/src/Probe"
  if ! dotnet pack "$ni_out/src/Probe/Probe.csproj" -c Release -nologo -o "$ni_out/feed" "-p:Version=$ni_version" > "$ni_out/pack.log" 2>&1; then
    bad "nuget isolation: the probe package did not pack (see $ni_out/pack.log)"; return 0
  fi

  if ni_restore_probe "$ni_out/run" "$ni_out/feed" "$ni_version" env && [ -d "$NUGET_PACKAGES/$ni_probe_id/$ni_version" ]; then
    pass "nuget isolation: a package built and restored by the run lands in $NUGET_PACKAGES"
  else
    bad "nuget isolation: the probe package is not in $NUGET_PACKAGES (see $ni_out/run/restore.log)"
  fi

  if ni_leaked=$(ni_leaks "$ni_machine" "$ni_out/feed" "$@"); then
    if [ -z "$ni_leaked" ]; then pass "nuget isolation: no package built by the run is in $ni_machine"
    else bad "nuget isolation: $ni_machine holds packages this run built; a restore anywhere on the machine resolves them: $(echo $ni_leaked)"; fi
  else
    bad "nuget isolation: found no built package to look for under $*"
  fi

  # The check must report a leak: the same restore without the run's folder, in a copy whose
  # nuget.config makes a scratch directory the machine's folder.
  mkdir -p "$ni_out/leak"
  printf '<configuration>\n  <config>\n    <add key="globalPackagesFolder" value="machine-packages" />\n  </config>\n</configuration>\n' > "$ni_out/leak/nuget.config"
  ni_restore_probe "$ni_out/leak" "$ni_out/feed" "$ni_version" env -u NUGET_PACKAGES -u NUGET_FALLBACK_PACKAGES || true
  ni_scratch=$(ni_machine_folder "$ni_out/leak")
  ni_leaked=$(ni_leaks "$ni_scratch" "$ni_out/feed" || true)
  case "$ni_scratch" in
    */nuget-isolation/leak/machine-packages)
      [ "$ni_leaked" = "$ni_probe_id $ni_version" ] && pass "nuget isolation: the check reports a package that a restore without the run's folder leaves behind" \
        || bad "nuget isolation: the check missed a leaked package (got '$ni_leaked', see $ni_out/leak/restore.log)" ;;
    *) bad "nuget isolation: the leak copy resolved its machine folder to '$ni_scratch'" ;;
  esac
}

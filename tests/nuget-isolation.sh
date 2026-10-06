# NuGet isolation: a run restores into a packages folder and an HTTP cache of its own, reads third-party
# packages from a shared fallback folder the tests own, and at its end moves the packages it downloaded
# from an https feed into that folder. A package built here never reaches the machine's global-packages
# folder, nor the shared folder.
# Sourced by tests/run.sh, tests/manager.sh and tests/nuget-isolation.test.sh: uses their pass, bad and $here.
#   MSBUILDKIT_TESTS_NUGET_SHARED_DIR      the shared folder (default dist/nuget-shared)
#   MSBUILDKIT_TESTS_KIT_PACKAGE_PREFIXES  ';'-separated id prefixes never put into it (default below)

ni_fixture="$here/tests/fixtures/NuGetIsolation"
ni_probe_id=dragoant.fixture.cacheprobe
ni_marker=.msbuildkit-nuget-run
ni_default_prefixes='DragoAnt.MSBuildKit;DragoAnt.Fixture.;DragoAnt.Samples.'

ni_native() { if command -v cygpath > /dev/null 2>&1; then cygpath -m "$1"; else printf '%s\n' "$1"; fi; }

# ni_norm <path>: absolute, forward slashes, no trailing slash, lower case where the file system ignores case.
ni_norm() {
  ni_p=$(printf '%s' "$1" | tr '\\' '/')
  if command -v cygpath > /dev/null 2>&1; then ni_p=$(cygpath -u "$ni_p"); fi
  case "$ni_p" in /*) ;; *) ni_p="$PWD/$ni_p" ;; esac
  ni_rest=""
  while [ ! -d "$ni_p" ]; do ni_rest="/${ni_p##*/}$ni_rest"; ni_p=${ni_p%/*}; [ -n "$ni_p" ] || ni_p=/; done
  ni_p=$(cd "$ni_p" && pwd -P); ni_p=$(ni_native "${ni_p%/}$ni_rest" | sed 's:/\.\{0,1\}$::; s:/\./:/:g; s:/*$::')
  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*|Darwin) printf '%s\n' "$ni_p" | tr '[:upper:]' '[:lower:]' ;;
    *) printf '%s\n' "${ni_p:-/}" ;;
  esac
}

# The global-packages folder NuGet uses under <dir> when no caller overrides it.
ni_machine_folder() {
  (cd "$1" && env -u NUGET_PACKAGES dotnet nuget locals global-packages --list) | tr -d '\r' \
    | sed -n 's/^global-packages: //p' | tr '\\' '/' | sed 's:/*$::'
}

ni_shared_dir() { printf '%s\n' "${MSBUILDKIT_TESTS_NUGET_SHARED_DIR:-$here/dist/nuget-shared}"; }

# ni_check_shared <shared> <machine>: fails when both name the same folder.
ni_check_shared() {
  [ "$(ni_norm "$1")" != "$(ni_norm "$2")" ] && return 0
  echo "nuget isolation: the shared folder $1 is the machine's global-packages folder; set MSBUILDKIT_TESTS_NUGET_SHARED_DIR to another folder" >&2
  return 1
}

# Reads package folder names (ids) on stdin; prints those that start (kit) or do not start (other) with a kit prefix.
ni_filter_ids() {
  awk -v want="$1" -v list="$(printf '%s' "${MSBUILDKIT_TESTS_KIT_PACKAGE_PREFIXES-$ni_default_prefixes}" | tr ';,' '  ')" '
    BEGIN { n = split(tolower(list), p, " ") }
    { kit = 0; id = tolower($0); for (i = 1; i <= n; i++) if (index(id, p[i]) == 1) kit = 1
      if ((want == "kit") == kit) print }'
}

ni_hash() {
  if command -v sha256sum > /dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
  else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

# ni_sweep <dir>: removes the folders under <dir> that a run marked as its own and that outlived it.
ni_sweep() {
  [ -d "$1" ] || return 0
  for ni_d in "$1"/*/ "$1"/.[!.]*/; do
    [ -f "$ni_d$ni_marker" ] || continue
    ni_pid=$(sed -n 's/^pid=//p' "$ni_d$ni_marker")
    if [ "$ni_pid" != "$$" ] && ! kill -0 "$ni_pid" 2> /dev/null; then rm -rf "$ni_d"; fi
  done
}

ni_take_tree() { mv "$1" "$2"; }

# ni_harvest <packages-dir> <shared-dir>: moves every package <packages-dir> downloaded from an https feed
# that is not a kit package and not yet shared into <shared-dir>; prints how many. Each package is
# staged first and published with one rename, so a reader or a parallel run sees it whole or not at all.
ni_harvest() {
  ni_count=0
  mkdir -p "$2/.staging"; ni_stage=$(mktemp -d "$2/.staging/$$.XXXXXX")
  printf 'pid=%s\n' "$$" > "$ni_stage/$ni_marker"
  ni_others=" $(ls -1 "$1" 2> /dev/null | ni_filter_ids other | tr '\n' ' ') "
  for ni_meta in "$1"/*/*/.nupkg.metadata; do [ ! -f "$ni_meta" ] || printf '%s\n' "$ni_meta"; done > "$ni_stage/metadata"
  awk '{ file = $0; source = ""
         while ((getline line < file) > 0) if (match(line, /"source"[ \t]*:[ \t]*"[^"]*"/)) { source = substr(line, RSTART, RLENGTH); sub(/^"source"[ \t]*:[ \t]*"/, "", source); sub(/"$/, "", source) }
         close(file); sub(/\/\.nupkg\.metadata$/, "", file); print tolower(source) "\t" file }' "$ni_stage/metadata" > "$ni_stage/sources"
  while IFS='	' read -r ni_source ni_vdir; do
    ni_ver=${ni_vdir##*/}; ni_id=${ni_vdir%/*}; ni_id=${ni_id##*/}
    case "$ni_others" in *" $ni_id "*) ;; *) continue ;; esac
    case "$ni_source" in
      https://localhost|https://localhost[:/]*|https://127.*|https://\[::1\]*) continue ;;
      https://*) ;;
      *) continue ;;
    esac
    [ ! -e "$2/$ni_id/$ni_ver" ] || continue
    mkdir -p "$ni_stage/$ni_id" "$2/$ni_id"
    if ni_take_tree "$ni_vdir" "$ni_stage/$ni_id/$ni_ver" && mv "$ni_stage/$ni_id/$ni_ver" "$2/$ni_id/" 2> /dev/null; then
      ni_count=$((ni_count+1))
    fi
  done < "$ni_stage/sources"
  rm -rf "$ni_stage"
  echo "$ni_count"
}

# ni_begin <name> <fallback|no-fallback>: fallback reads and fills the shared folder.
ni_begin() {
  ni_machine=$(ni_machine_folder "$here")
  [ -n "$ni_machine" ] || { echo "nuget isolation: cannot find the machine's global-packages folder" >&2; exit 1; }
  ni_shared=""
  if [ "$2" = fallback ] && [ -z "${NUGET_FALLBACK_PACKAGES:-}" ]; then
    ni_shared=$(ni_shared_dir)
    ni_check_shared "$ni_shared" "$ni_machine" || exit 1
  fi
  ni_runs="$here/dist/nuget-runs"
  ni_sweep "$ni_runs"
  ni_run="$ni_runs/$1.$$.$(date +%s)"; ni_own=""
  mkdir -p "$ni_run"; printf 'pid=%s\n' "$$" > "$ni_run/$ni_marker"
  trap ni_end EXIT
  trap 'exit 129' HUP; trap 'exit 130' INT; trap 'exit 143' TERM
  ni_snapshot "$ni_machine" > "$ni_run/machine-before"
  if [ -n "${NUGET_PACKAGES:-}" ]; then
    echo "NOTE  NUGET_PACKAGES is set: restoring into $NUGET_PACKAGES, nothing is shared"
    ni_shared=""
  else
    ni_own="$ni_run/packages"; mkdir -p "$ni_own"
    NUGET_PACKAGES=$(ni_native "$ni_own"); export NUGET_PACKAGES
  fi
  if [ -z "${NUGET_HTTP_CACHE_PATH:-}" ]; then
    mkdir -p "$ni_run/http-cache"; NUGET_HTTP_CACHE_PATH=$(ni_native "$ni_run/http-cache"); export NUGET_HTTP_CACHE_PATH
  fi
  if [ -n "$ni_shared" ]; then
    mkdir -p "$ni_shared"; ni_sweep "$ni_shared/.staging"
    NUGET_FALLBACK_PACKAGES=$(ni_native "$ni_shared"); export NUGET_FALLBACK_PACKAGES
  fi
}

ni_end() {
  if [ -n "${ni_own:-}" ] && [ -n "${ni_shared:-}" ]; then
    ni_moved=$(ni_harvest "$ni_own" "$ni_shared") || ni_moved="?"
    echo "NOTE  $ni_moved downloaded package(s) moved into the shared folder $ni_shared"
  fi
  [ -z "${ni_run:-}" ] || rm -rf "$ni_run" || echo "NOTE  could not remove $ni_run"
  ni_own=""; ni_shared=""; ni_run=""
}

# The packages folder of the run: the one place a test reads restored packages from.
ni_packages_dir() { printf '%s\n' "${NUGET_PACKAGES:-$ni_machine}"; }

# ni_snapshot <folder>: "<id>/<version> <sha256 of its nupkg, or ->" for every kit package in <folder>.
ni_snapshot() {
  [ -d "$1" ] || return 0
  ls -1 "$1" | ni_filter_ids kit | while IFS= read -r ni_id; do
    for ni_vdir in "$1/$ni_id"/*/; do
      [ -d "$ni_vdir" ] || continue
      ni_ver=${ni_vdir%/}; ni_ver=${ni_ver##*/}; ni_pkg="$1/$ni_id/$ni_ver/$ni_id.$ni_ver.nupkg"
      if [ -f "$ni_pkg" ]; then echo "$ni_id/$ni_ver $(ni_hash "$ni_pkg")"; else echo "$ni_id/$ni_ver -"; fi
    done
  done | LC_ALL=C sort
}

# ni_packed <dir>...: "<id>/<version> <sha256>" for every package file under the directories.
ni_packed() {
  find "$@" -name '*.nupkg' 2> /dev/null | while IFS= read -r ni_file; do
    unzip -p "$ni_file" '*.nuspec' | tr -d '\r' | awk -v hash="$(ni_hash "$ni_file")" '
      match($0, /<id>[^<]*<\/id>/) && id == "" { id = substr($0, RSTART + 4, RLENGTH - 9) }
      match($0, /<version>[^<]*<\/version>/) && version == "" { version = substr($0, RSTART + 9, RLENGTH - 19) }
      END { sub(/\+.*/, "", version); print tolower(id) "/" tolower(version), hash }'
  done | LC_ALL=C sort -u
}

# ni_guard <folder> <snapshot-before> <packed>: prints every way <folder> differs from the snapshot, and
# every package in it that the run packed; fails when there is any.
ni_guard() {
  ni_snapshot "$1" > "$2.after"
  cut -d' ' -f1 "$3" | sed 's:/.*::' | ni_filter_ids other | LC_ALL=C sort -u > "$2.other"
  {
    awk 'FILENAME == ARGV[1] { before[$1] = $2; next }
         FILENAME == ARGV[2] { after[$1] = $2; next }
         { packed[$2] = 1 }
         END {
           for (k in after) {
             mark = (after[k] in packed) ? " (the run packed it)" : ""
             if (!(k in before)) print "added " k mark
             else if (before[k] != after[k]) print "changed " k mark
           }
           for (k in before) if (!(k in after)) print "removed " k
         }' "$2" "$2.after" "$3"
    while read -r ni_key ni_sum; do
      ni_id=${ni_key%%/*}; ni_ver=${ni_key#*/}; ni_pkg="$1/$ni_id/$ni_ver/$ni_id.$ni_ver.nupkg"
      grep -qxF "$ni_id" "$2.other" || continue
      if [ -f "$ni_pkg" ] && [ "$(ni_hash "$ni_pkg")" = "$ni_sum" ]; then echo "holds $ni_key, which the run packed"; fi
    done < "$3"
  } | LC_ALL=C sort > "$2.problems"
  cat "$2.problems"
  [ ! -s "$2.problems" ]
}

# ni_hardcoded <machine-folder> <dir>...: test files that name a packages folder instead of using ni_packages_dir.
ni_hardcoded() {
  ni_m=$1; shift
  ni_mb=$(printf '%s' "$ni_m" | tr '/' '\\')
  grep -rnIiE --exclude-dir=bin --exclude-dir=obj --exclude-dir=dist --exclude-dir=.toolkit --exclude-dir=TestResults \
    --exclude=nuget-isolation.sh --exclude=nuget-isolation.test.sh \
    -e '\.nuget[/\\]+packages' -e '\$\{?NUGET_PACKAGES' -e '"NUGET_PACKAGES"' -e 'NuGetPackageRoot' \
    -e "$(printf '%s' "$ni_m" | sed 's/[][\\.*^$+?(){}|]/\\&/g')" -e "$(printf '%s' "$ni_mb" | sed 's/[][\\.*^$+?(){}|]/\\&/g')" \
    "$@" 2> /dev/null || true
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

  ni_target=$(ni_packages_dir)
  if ni_restore_probe "$ni_out/run" "$ni_out/feed" "$ni_version" env && [ -d "$ni_target/$ni_probe_id/$ni_version" ]; then
    pass "nuget isolation: a package built and restored by the run lands in $ni_target"
  else
    bad "nuget isolation: the probe package is not in $ni_target (see $ni_out/run/restore.log)"
  fi

  ni_packed "$ni_out/feed" "$@" > "$ni_out/packed"
  if ! grep -q "^$ni_probe_id/" "$ni_out/packed"; then
    bad "nuget isolation: found no built package under $*"
  elif ni_problems=$(ni_guard "$ni_machine" "$ni_run/machine-before" "$ni_out/packed"); then
    pass "nuget isolation: the kit packages in $ni_machine are as before the run, and it holds none the run built"
  else
    bad "nuget isolation: the run changed $ni_machine: $(echo $ni_problems)"
  fi

  # The guard must fire: the same restore without the run's folders, into a stand-in for the machine's
  # folder that a nuget.config names.
  mkdir -p "$ni_out/leak"
  printf '<configuration>\n  <config>\n    <add key="globalPackagesFolder" value="machine-packages" />\n  </config>\n</configuration>\n' > "$ni_out/leak/nuget.config"
  ni_fake=$(ni_machine_folder "$ni_out/leak")
  ni_snapshot "$ni_fake" > "$ni_out/leak-before"
  ni_restore_probe "$ni_out/leak" "$ni_out/feed" "$ni_version" env -u NUGET_PACKAGES -u NUGET_FALLBACK_PACKAGES || true
  ni_problems=$(ni_guard "$ni_fake" "$ni_out/leak-before" "$ni_out/packed" || true)
  case "$ni_fake" in
    */nuget-isolation/leak/machine-packages)
      [ "$ni_problems" = "added $ni_probe_id/$ni_version (the run packed it)" ] \
        && pass "nuget isolation: the guard reports a package that a restore without the run's folders leaves behind" \
        || bad "nuget isolation: the guard missed a leaked package (got '$ni_problems', see $ni_out/leak/restore.log)" ;;
    *) bad "nuget isolation: the stand-in resolved the machine's folder to '$ni_fake'" ;;
  esac

  ni_found=$(ni_hardcoded "$ni_machine" "$here/tests" "$here/manager/tests" "$here/samples")
  [ -z "$ni_found" ] && pass "nuget isolation: every test reads restored packages through ni_packages_dir" \
    || bad "nuget isolation: tests name a packages folder themselves: $(echo $ni_found)"
}

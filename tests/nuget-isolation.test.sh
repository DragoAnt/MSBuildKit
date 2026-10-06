#!/bin/sh
# Unit checks of tests/nuget-isolation.sh on hand-made package folders: no dotnet, no network, and
# never the machine's global-packages folder (a stub stands in for it).
# Usage: sh tests/nuget-isolation.test.sh
set -eu

here=$(cd "$(dirname "$0")/.." && pwd)
failures=0
pass() { echo "PASS  nuget isolation: $*"; }
bad() { echo "FAIL  nuget isolation: $*"; failures=$((failures+1)); }

. "$here/tests/nuget-isolation.sh"

t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
unset NUGET_PACKAGES NUGET_FALLBACK_PACKAGES NUGET_HTTP_CACHE_PATH MSBUILDKIT_TESTS_NUGET_SHARED_DIR MSBUILDKIT_TESTS_KIT_PACKAGE_PREFIXES || true

# mkpkg <folder> <id> <version> <source|none>: a package as NuGet extracts it into a packages folder.
mkpkg() {
  d="$1/$2/$3"; mkdir -p "$d/lib/net8.0"
  printf 'nupkg %s %s\n' "$2" "$3" > "$d/$2.$3.nupkg"
  printf 'sha512\n' > "$d/$2.$3.nupkg.sha512"
  printf '<package/>\n' > "$d/$2.nuspec"
  printf 'dll\n' > "$d/lib/net8.0/$2.dll"
  [ "$4" = none ] || printf '{\n  "version": 2,\n  "contentHash": "x",\n  "source": "%s"\n}\n' "$4" > "$d/.nupkg.metadata"
}
listing() { (cd "$1" && find . -type f | LC_ALL=C sort); }
nuget_org=https://api.nuget.org/v3/index.json

# --- harvest: only https downloads, never a kit package -----------------------------------------
src="$t/h/run"; shared="$t/h/shared"
mkpkg "$src" newtonsoft.json 13.0.3 "$nuget_org"
mkpkg "$src" xunit.v3 4.0.1 "HTTPS://Example.ORG/v3/index.json"
mkpkg "$src" loop.localhost 1.0.0 https://localhost:5001/v3/index.json
mkpkg "$src" loop.ipv4 1.0.0 https://127.0.0.1/v3/index.json
mkpkg "$src" loop.ipv6 1.0.0 'https://[::1]:8443/v3/index.json'
mkpkg "$src" plain.http 1.0.0 http://feed.example.org/v3/index.json
mkpkg "$src" local.windows 1.0.0 'C:\\src\\repo\\dist\\feed'
mkpkg "$src" local.posix 1.0.0 /home/user/repo/dist/manager/feed
mkpkg "$src" dragoant.msbuildkit.manager 1.0.0 "$nuget_org"
mkpkg "$src" dragoant.fixture.cacheprobe 1.0.0 "$nuget_org"
mkpkg "$src" dragoant.samples.minimallibrary 0.1.0 "$nuget_org"
mkpkg "$src" no.metadata 1.0.0 none
moved=$(ni_harvest "$src" "$shared") || moved=error
got=$(cd "$shared" && find . -mindepth 2 -maxdepth 2 -type d ! -path './.staging*' | sed 's|^\./||' | LC_ALL=C sort | tr '\n' ' ') || got=error
[ "$got" = "newtonsoft.json/13.0.3 xunit.v3/4.0.1 " ] && [ "$moved" = 2 ] \
  && pass "harvest takes the packages downloaded from an https feed and nothing else" \
  || bad "harvest took '$got' (reported $moved), expected newtonsoft.json/13.0.3 xunit.v3/4.0.1"
[ "$(listing "$shared/newtonsoft.json/13.0.3")" = "$(printf '%s\n' ./.nupkg.metadata ./lib/net8.0/newtonsoft.json.dll ./newtonsoft.json.13.0.3.nupkg ./newtonsoft.json.13.0.3.nupkg.sha512 ./newtonsoft.json.nuspec)" ] \
  && pass "a harvested package keeps every file of its folder" || bad "a harvested package lost files: $(listing "$shared/newtonsoft.json/13.0.3" | tr '\n' ' ')"
[ -z "$(ls -A "$shared/.staging" 2> /dev/null)" ] && pass "harvest leaves no staging folder behind" || bad "harvest left $(ls -A "$shared/.staging")"

src="$t/p/run"; shared="$t/p/shared"
mkpkg "$src" newtonsoft.json 13.0.3 "$nuget_org"
mkpkg "$src" dragoant.msbuildkit.manager 1.0.0 "$nuget_org"
moved=$(MSBUILDKIT_TESTS_KIT_PACKAGE_PREFIXES='Newtonsoft.' ni_harvest "$src" "$shared") || moved=error
[ -d "$shared/dragoant.msbuildkit.manager/1.0.0" ] && [ ! -d "$shared/newtonsoft.json" ] \
  && pass "MSBUILDKIT_TESTS_KIT_PACKAGE_PREFIXES replaces the kit prefixes" || bad "the prefix override was ignored (moved $moved)"

src="$t/k/run"; shared="$t/k/shared"
mkpkg "$src" newtonsoft.json 13.0.3 "$nuget_org"
mkdir -p "$shared/newtonsoft.json/13.0.3"; printf 'kept\n' > "$shared/newtonsoft.json/13.0.3/marker"
moved=$(ni_harvest "$src" "$shared") || moved=error
[ "$moved" = 0 ] && [ "$(listing "$shared/newtonsoft.json/13.0.3")" = ./marker ] \
  && pass "harvest never replaces a package the shared folder already holds" || bad "harvest replaced an existing package (moved $moved)"

# --- two runs harvest the same packages at once --------------------------------------------------
shared="$t/par/shared"
for run in a b; do
  i=0; while [ $i -lt 25 ]; do mkpkg "$t/par/$run" "pkg.$i" 1.0.$i "$nuget_org"; i=$((i+1)); done
done
expected=$(listing "$t/par/a/pkg.7/1.0.7")
(ni_harvest "$t/par/a" "$shared" > "$t/par/a.out") & pa=$!
(ni_harvest "$t/par/b" "$shared" > "$t/par/b.out") & pb=$!
wait $pa; wait $pb
total=$(( $(cat "$t/par/a.out") + $(cat "$t/par/b.out") ))
broken=""
i=0; while [ $i -lt 25 ]; do
  [ "$(listing "$shared/pkg.$i/1.0.$i" | sed "s/pkg\.$i/pkg.7/g; s/1\.0\.$i/1.0.7/g")" = "$expected" ] || broken="$broken pkg.$i"
  i=$((i+1))
done
[ -z "$broken" ] && [ "$total" = 25 ] && [ -z "$(ls -A "$shared/.staging" 2> /dev/null)" ] \
  && pass "two runs harvesting at once leave every package whole, once" \
  || bad "parallel harvest: moved $total of 25, broken:${broken:- none}, staging: $(ls -A "$shared/.staging" 2> /dev/null | tr '\n' ' ')"

# A harvest killed half-way through a copy leaves nothing under the package's final name.
src="$t/x/run"; shared="$t/x/shared"
mkpkg "$src" newtonsoft.json 13.0.3 "$nuget_org"
(
  ni_take_tree() { mkdir -p "$2"; cp "$1/.nupkg.metadata" "$2/"; exit 9; }
  ni_harvest "$src" "$shared" > /dev/null
) || true
[ ! -e "$shared/newtonsoft.json/13.0.3" ] && pass "a harvest killed during a copy publishes nothing" \
  || bad "a killed harvest left $(listing "$shared/newtonsoft.json/13.0.3" | tr '\n' ' ') under the final name"

# --- leftovers of killed runs --------------------------------------------------------------------
root="$t/s"
sh -c 'exit 0' & dead=$!; wait $dead
sleep 300 & live=$!
mkdir -p "$root/dead" "$root/live" "$root/foreign"
printf 'pid=%s\n' "$dead" > "$root/dead/$ni_marker"
printf 'pid=%s\n' "$live" > "$root/live/$ni_marker"
printf 'not a run\n' > "$root/foreign/readme"; printf 'x\n' > "$root/file"
ni_sweep "$root"
kill "$live" 2> /dev/null || true
[ ! -e "$root/dead" ] && [ -d "$root/live" ] && [ -f "$root/foreign/readme" ] && [ -f "$root/file" ] \
  && pass "the start-up sweep removes only marked folders of runs that are gone" \
  || bad "sweep left: $(ls -A "$root" | tr '\n' ' ')"

# --- the run lifecycle, with a stub for the machine's folder --------------------------------------
repo="$t/repo"; machine="$t/machine"; mkdir -p "$repo/dist" "$machine/somepkg/1.0.0"
printf 'machine\n' > "$machine/somepkg/1.0.0/file"
machine_before=$(listing "$machine")
cat > "$t/runner.sh" <<'EOF'
# runner.sh <repo> <machine> <exit|term|kill> <env-out> <kit-checkout>: begins isolation, downloads one
# package, then ends as asked.
set -eu
here=$1; machine=$2
. "$5/tests/nuget-isolation.sh"
ni_machine_folder() { printf '%s\n' "$machine"; }
ni_begin lifecycle fallback
env | grep '^NUGET_' | LC_ALL=C sort > "$4"
d="$(ni_packages_dir)/newtonsoft.json/13.0.3"; mkdir -p "$d"
printf '{"version": 2, "source": "https://api.nuget.org/v3/index.json"}\n' > "$d/.nupkg.metadata"
case "$3" in
  exit) exit 0 ;;
  term) kill -TERM $$; sleep 30 ;;
  kill) kill -KILL $$ ;;
esac
EOF
lifecycle() { sh "$t/runner.sh" "$repo" "$machine" "$1" "$t/env.$1" "$here" > /dev/null 2>&1 || true; }
lifecycle exit
grep -q "^NUGET_PACKAGES=.*/dist/nuget-runs/lifecycle\.[0-9]*\.[0-9]*/packages$" "$t/env.exit" \
  && grep -q "^NUGET_HTTP_CACHE_PATH=.*/dist/nuget-runs/lifecycle\.[0-9]*\.[0-9]*/http-cache$" "$t/env.exit" \
  && grep -q "^NUGET_FALLBACK_PACKAGES=.*/dist/nuget-shared$" "$t/env.exit" \
  && pass "a run gets its own packages and HTTP cache folders and reads the shared folder" \
  || bad "the run's NuGet variables: $(tr '\n' ' ' < "$t/env.exit")"
[ -d "$repo/dist/nuget-shared/newtonsoft.json/13.0.3" ] && [ -z "$(ls -A "$repo/dist/nuget-runs")" ] \
  && pass "the end of a run harvests into the shared folder and removes the run's folders" \
  || bad "after a run: shared $(ls -A "$repo/dist/nuget-shared" | tr '\n' ' '), runs $(ls -A "$repo/dist/nuget-runs" | tr '\n' ' ')"
rm -rf "$repo/dist"; mkdir -p "$repo/dist"
lifecycle term
[ -z "$(ls -A "$repo/dist/nuget-runs")" ] && pass "a terminated run still removes its folders" \
  || bad "a terminated run left $(ls -A "$repo/dist/nuget-runs" | tr '\n' ' ')"
lifecycle kill
left=$(ls -A "$repo/dist/nuget-runs")
lifecycle exit
[ -n "$left" ] && [ -z "$(ls -A "$repo/dist/nuget-runs")" ] && pass "the next run removes the folders a killed run left" \
  || bad "killed run left '$left'; after the next run: $(ls -A "$repo/dist/nuget-runs" | tr '\n' ' ')"
[ "$(listing "$machine")" = "$machine_before" ] && pass "no run touched the machine's folder" || bad "the machine's folder changed"

# --- the shared folder is never the machine's folder ---------------------------------------------
refused=0
for candidate in "$machine" "$machine/" "$machine/./" "$(printf '%s' "$machine" | tr '/' '\\')"; do
  ni_check_shared "$candidate" "$machine" 2> /dev/null && bad "the shared folder '$candidate' was accepted as the machine's folder" || refused=$((refused+1))
done
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*|Darwin)
  ni_check_shared "$(printf '%s' "$machine" | tr '[:lower:]' '[:upper:]')" "$machine" 2> /dev/null \
    && bad "an upper-case spelling of the machine's folder was accepted" || refused=$((refused+1)) ;;
esac
ni_check_shared "$t/elsewhere/new" "$machine" && accepted=1 || accepted=0
[ "$accepted" = 1 ] && [ "$refused" -ge 4 ] && pass "the shared folder may not be the machine's folder, however it is spelled" \
  || bad "refused $refused spellings, accepted a fresh folder: $accepted"
(
  here="$repo"
  ni_machine_folder() { printf '%s\n' "$machine"; }
  MSBUILDKIT_TESTS_NUGET_SHARED_DIR="$machine/"
  ni_begin refused fallback
) > "$t/refused.log" 2>&1 && bad "a run with the machine's folder as its shared folder started" \
  || { grep -q "machine" "$t/refused.log" && pass "a run refuses the machine's folder as its shared folder" || bad "refusal without a reason: $(cat "$t/refused.log")"; }
[ "$(listing "$machine")" = "$machine_before" ] && pass "the refused run left the machine's folder alone" || bad "the refused run changed the machine's folder"

# --- one accessor for the packages folder --------------------------------------------------------
scan="$t/scan"; mkdir -p "$scan/tests" "$scan/obj"
printf 'ls "$HOME/.nu''get/packages"\n' > "$scan/tests/home.sh"
printf 'ls "$%s/x"\n' "{NUGET_PACKAGES}" > "$scan/tests/env.sh"
printf 'var p = "%s";\n' "$machine" > "$scan/tests/Literal.cs"
printf 'ls "$(ni_packages_dir)/x"\n' > "$scan/tests/good.sh"
printf '{"packageFolders": {"%s": {}}}\n' "$machine" > "$scan/obj/project.assets.json"
hits=$(ni_hardcoded "$machine" "$scan" | sed 's|^.*/scan/||; s|:.*||' | LC_ALL=C sort | tr '\n' ' ')
[ "$hits" = "tests/Literal.cs tests/env.sh tests/home.sh " ] && pass "the check finds a test that names a packages folder itself" \
  || bad "the hard-coded-folder check reported '$hits'"

# --- the machine-folder guard --------------------------------------------------------------------
fake="$t/fake-machine"
mkpkg "$fake" dragoant.msbuildkit.manager 0.1.0 "$nuget_org"
mkpkg "$fake" newtonsoft.json 13.0.3 "$nuget_org"
ni_snapshot "$fake" > "$t/before"
[ "$(cut -d' ' -f1 "$t/before")" = dragoant.msbuildkit.manager/0.1.0 ] && pass "the snapshot lists the kit packages only" || bad "snapshot: $(cat "$t/before")"
mkdir -p "$t/feed"
printf 'built probe\n' > "$t/feed/probe.nupkg"; printf 'built other\n' > "$t/feed/other.nupkg"
printf '%s %s\n' dragoant.fixture.cacheprobe/1.0.0 "$(ni_hash "$t/feed/probe.nupkg")" badpackage/1.0.0 "$(ni_hash "$t/feed/other.nupkg")" > "$t/packed"
ni_guard "$fake" "$t/before" "$t/packed" > "$t/guard.clean" && [ ! -s "$t/guard.clean" ] && pass "the guard is quiet when nothing changed" || bad "guard on an unchanged folder: $(cat "$t/guard.clean")"
mkpkg "$fake" dragoant.fixture.cacheprobe 1.0.0 none; cp "$t/feed/probe.nupkg" "$fake/dragoant.fixture.cacheprobe/1.0.0/dragoant.fixture.cacheprobe.1.0.0.nupkg"
mkpkg "$fake" badpackage 1.0.0 none; cp "$t/feed/other.nupkg" "$fake/badpackage/1.0.0/badpackage.1.0.0.nupkg"
printf 'changed\n' > "$fake/dragoant.msbuildkit.manager/0.1.0/dragoant.msbuildkit.manager.0.1.0.nupkg"
mkpkg "$fake" newtonsoft.json 13.0.4 "$nuget_org"
if ni_guard "$fake" "$t/before" "$t/packed" > "$t/guard.red"; then bad "the guard passed a changed machine folder"; fi
for want in "added dragoant.fixture.cacheprobe/1.0.0 (the run packed it)" "changed dragoant.msbuildkit.manager/0.1.0" "holds badpackage/1.0.0, which the run packed"; do
  grep -qxF "$want" "$t/guard.red" && pass "the guard reports: $want" || bad "the guard missed '$want': $(tr '\n' ';' < "$t/guard.red")"
done
grep -q newtonsoft "$t/guard.red" && bad "the guard reported a third-party package" || pass "the guard ignores third-party packages"

echo
if [ "$failures" -eq 0 ]; then echo "nuget isolation unit checks: all passed"; else echo "nuget isolation unit checks: $failures failure(s)"; exit 1; fi

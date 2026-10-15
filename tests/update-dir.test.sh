#!/bin/sh
# The kit folder of update.sh and update.ps1: a fresh install writes .mskit/, --kit-dir picks another
# name and kit.json remembers it, an older .toolkit/ install moves, and 0.2.1 reaches .mskit/ in two runs.
# A run stopped after the move, or by a signal, is finished by the next one.
# No dotnet, no network: every run installs from the working-tree kit, a "download" from a local curl stand-in.
# update.ps1 runs when pwsh exists.
# Usage: sh tests/update-dir.test.sh
set -eu

here=$(cd "$(dirname "$0")/.." && pwd)
kit="$here/kit"
failures=0
pass() { echo "PASS  update dir: $*"; }
bad() { echo "FAIL  update dir: $*"; failures=$((failures+1)); }

t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT

impls="sh"
if command -v pwsh > /dev/null 2>&1; then impls="sh ps1"; else echo "SKIP  update dir: update.ps1 cases (no pwsh)"; fi

# upd <impl> <dir> <script folder: kit | a folder of <dir>> [--kit-dir NAME] [--dry-run]
upd() {
  impl="$1"; dir="$2"; where="$3"; shift 3
  kd=""; dry=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --kit-dir) kd="$2"; shift 2 ;;
      --dry-run) dry=1; shift ;;
      *) echo "upd: unknown argument $1" >&2; return 2 ;;
    esac
  done
  if [ "$where" = kit ]; then folder="$kit/.toolkit"; else folder="$where"; fi
  if [ "$impl" = sh ]; then
    (cd "$dir" && sh "$folder/update.sh" --source "$kit" ${kd:+--kit-dir "$kd"} ${dry:+--dry-run})
  else
    (cd "$dir" && pwsh -NoProfile -NonInteractive -File "$folder/update.ps1" -Source "$kit" ${kd:+-KitDir "$kd"} ${dry:+-DryRun})
  fi
}

kitdir_of() { sed -n 's/.*"kitDir"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$1" 2>/dev/null | head -n 1; }
has() { grep -qF -- "$2" "$1" 2>/dev/null; }
snapshot() { (cd "$1" && find . -path ./.git -prune -o -type f -print | LC_ALL=C sort | while IFS= read -r f; do printf '%s ' "$f"; cksum < "$f"; done); }

# A consumer installed by a release before 0.3: .toolkit/ whose kit.json names no kitDir.
legacy() {
  dir="$1"; rm -rf "$dir"; mkdir -p "$dir"
  sh "$kit/.toolkit/update.sh" --source "$kit" --root "$dir" --kit-dir .toolkit > "$dir.seed.log" 2>&1 \
    || sh "$kit/.toolkit/update.sh" --source "$kit" --root "$dir" > "$dir.seed.log" 2>&1
  if [ ! -d "$dir/.toolkit" ] && [ -d "$dir/.mskit" ]; then mv "$dir/.mskit" "$dir/.toolkit"; fi
  sed '/"kitDir"/d; s/\(\]\),$/\1/' "$dir/.toolkit/kit.json" > "$dir/kit.json.tmp" && mv "$dir/kit.json.tmp" "$dir/.toolkit/kit.json"
  printf '<Project>\n  <Import Project="$(MSBuildThisFileDirectory).toolkit/msbuild/init.props" />\n</Project>\n' > "$dir/Directory.Build.props"
  printf '<Project>\n  <Import Project="$(MSBuildThisFileDirectory).toolkit\\msbuild\\init.targets" />\n</Project>\n' > "$dir/Directory.Build.targets"
  mkdir -p "$dir/.toolkit/.local/LocalCompile"
  printf 'template\n' > "$dir/.toolkit/.local/LocalCompile/Local.cs"
}

for impl in $impls; do
  # --- a fresh install writes .mskit/ ---------------------------------------------------------
  d="$t/$impl-fresh"; mkdir -p "$d"
  status=0; upd "$impl" "$d" kit > "$d.log" 2>&1 || status=$?
  if [ "$status" -eq 0 ] && [ -f "$d/.mskit/kit.json" ] && [ ! -e "$d/.toolkit" ]; then pass "$impl: a fresh install writes .mskit/"
  else bad "$impl: a fresh install: exit $status (see log)"; tail -n 5 "$d.log"; fi
  [ "$(kitdir_of "$d/.mskit/kit.json")" = ".mskit" ] && pass "$impl: kit.json records kitDir .mskit" || bad "$impl: kit.json kitDir is '$(kitdir_of "$d/.mskit/kit.json")'"
  missing=""
  for f in kit.parts update.sh update.ps1 msbuild/init.props msbuild/init.targets res/package.icon.png; do [ -f "$d/.mskit/$f" ] || missing="$missing $f"; done
  [ -z "$missing" ] && pass "$impl: .mskit/ holds the kit, both updaters and res/" || bad "$impl: .mskit/ lacks$missing"
  has "$d/Directory.Build.props" '$(MSBuildThisFileDirectory).mskit/msbuild/init.props' \
    && has "$d/Directory.Build.targets" '$(MSBuildThisFileDirectory).mskit/msbuild/init.targets' \
    && pass "$impl: Directory.Build.props/targets import .mskit/msbuild/init.*" || bad "$impl: Directory.Build.* do not import .mskit"
  has "$d.log" "installed in" && has "$d.log" ".mskit" && ! has "$d.log" ".toolkit/" \
    && pass "$impl: the log names .mskit, never .toolkit" || bad "$impl: the log of a fresh install (see below)"

  # --- --kit-dir NAME, remembered for the next run --------------------------------------------
  d="$t/$impl-custom"; mkdir -p "$d"
  status=0; upd "$impl" "$d" kit --kit-dir build-kit > "$d.log" 2>&1 || status=$?
  [ "$status" -eq 0 ] && [ "$(kitdir_of "$d/build-kit/kit.json")" = "build-kit" ] && [ ! -e "$d/.mskit" ] \
    && has "$d/Directory.Build.props" '$(MSBuildThisFileDirectory)build-kit/msbuild/init.props' \
    && pass "$impl: --kit-dir build-kit installs there, records it and imports it" || { bad "$impl: --kit-dir build-kit: exit $status"; tail -n 5 "$d.log"; }
  status=0; upd "$impl" "$d" build-kit > "$d.again.log" 2>&1 || status=$?
  [ "$status" -eq 0 ] && [ ! -e "$d/.mskit" ] && [ ! -e "$d/build-kit/build-kit" ] && has "$d.again.log" "build-kit" \
    && pass "$impl: a later run without --kit-dir finds build-kit/ through kit.json" || { bad "$impl: rediscovery of build-kit: exit $status"; tail -n 5 "$d.again.log"; }

  for name in ../outside a/b; do
    d="$t/$impl-bad-name"; rm -rf "$d"; mkdir -p "$d"
    status=0; upd "$impl" "$d" kit --kit-dir "$name" > "$d.log" 2>&1 || status=$?
    [ "$status" -ne 0 ] && [ -z "$(ls -A "$d")" ] && [ ! -e "$t/outside" ] \
      && pass "$impl: --kit-dir '$name' is refused and nothing is written" || bad "$impl: --kit-dir '$name': exit $status, wrote $(ls -A "$d")"
  done

  d="$t/$impl-two-kits"; rm -rf "$d"; mkdir -p "$d/one" "$d/two"
  printf '{\n  "kitDir": "one"\n}\n' > "$d/one/kit.json"; printf '{\n  "kitDir": "two"\n}\n' > "$d/two/kit.json"
  status=0; upd "$impl" "$d" kit > "$d.log" 2>&1 || status=$?
  [ "$status" -ne 0 ] && { has "$d.log" "--kit-dir" || has "$d.log" "-KitDir"; } && [ ! -e "$d/.mskit" ] \
    && pass "$impl: two folders claiming the kit stop the run and ask for the folder" || { bad "$impl: two kit folders: exit $status"; tail -n 3 "$d.log"; }

  # --- migration of an untracked .toolkit/ ----------------------------------------------------
  d="$t/$impl-migrate"; legacy "$d"
  printf 'bin/\n.toolkit/\n/.toolkit/.local/secrets\nmy.toolkit/\n.toolkitx/\n' > "$d/.gitignore"
  mkdir -p "$d/.github"
  printf 'version: 2\nupdates:\n  - package-ecosystem: nuget\n    directory: "/.toolkit"\n' > "$d/.github/dependabot.yml"
  status=0; upd "$impl" "$d" .toolkit > "$d.log" 2>&1 || status=$?
  if [ "$status" -eq 0 ] && [ -f "$d/.mskit/kit.json" ] && [ ! -e "$d/.toolkit" ]; then pass "$impl: an untracked .toolkit/ moves to .mskit/"
  else bad "$impl: migration: exit $status, .toolkit $( [ -e "$d/.toolkit" ] && echo kept || echo gone)"; tail -n 8 "$d.log"; fi
  [ "$(kitdir_of "$d/.mskit/kit.json")" = ".mskit" ] && pass "$impl: the moved kit.json records kitDir .mskit" || bad "$impl: moved kit.json kitDir '$(kitdir_of "$d/.mskit/kit.json")'"
  has "$d/.mskit/.local/LocalCompile/Local.cs" template && pass "$impl: .local/ templates move with the kit" || bad "$impl: .local/ templates were lost"
  has "$d/Directory.Build.props" '$(MSBuildThisFileDirectory).mskit/msbuild/init.props' && ! has "$d/Directory.Build.props" .toolkit \
    && pass "$impl: Directory.Build.props import rewritten" || bad "$impl: Directory.Build.props: $(cat "$d/Directory.Build.props")"
  has "$d/Directory.Build.targets" '$(MSBuildThisFileDirectory).mskit\msbuild\init.targets' && ! has "$d/Directory.Build.targets" .toolkit \
    && pass "$impl: Directory.Build.targets import rewritten (backslash spelling kept)" || bad "$impl: Directory.Build.targets: $(cat "$d/Directory.Build.targets")"
  if [ "$(tr -d '\r' < "$d/.gitignore")" = "$(printf 'bin/\n.mskit/\n/.mskit/.local/secrets\nmy.toolkit/\n.toolkitx/')" ]; then pass "$impl: .gitignore lines rewritten, look-alike names untouched"
  else bad "$impl: .gitignore: $(tr '\n' '|' < "$d/.gitignore")"; fi
  has "$d/.github/dependabot.yml" 'directory: "/.mskit"' && pass "$impl: dependabot.yml rewritten" || bad "$impl: dependabot.yml: $(cat "$d/.github/dependabot.yml")"
  miss=""
  for word in "moved .toolkit/ to .mskit/" "rewrote" "Directory.Build.props" "Directory.Build.targets" ".gitignore" "dependabot.yml"; do
    has "$d.log" "$word" || miss="$miss '$word'"
  done
  has "$d.log" "add to Directory.Build" && miss="$miss (still asks to add an import)"
  [ -z "$miss" ] && pass "$impl: the migration log names the move and every rewritten file" || { bad "$impl: the migration log lacks$miss"; tail -n 12 "$d.log"; }

  # --- migration of a tracked .toolkit/ ------------------------------------------------------
  if command -v git > /dev/null 2>&1; then
    d="$t/$impl-tracked"; legacy "$d"
    git -C "$d" init -q && git -C "$d" add -A && git -C "$d" -c user.name=t -c user.email=t@example.invalid commit -qm seed
    status=0; upd "$impl" "$d" .toolkit > "$d.log" 2>&1 || status=$?
    renames=$(git -C "$d" status --porcelain | grep -c '^R  \.toolkit/.* -> \.mskit/' || true)
    [ "$status" -eq 0 ] && [ -z "$(git -C "$d" ls-files .toolkit)" ] && [ -n "$(git -C "$d" ls-files .mskit)" ] && [ "$renames" -gt 0 ] \
      && pass "$impl: a tracked .toolkit/ moves with git mv ($renames renames staged)" || { bad "$impl: tracked migration: exit $status, $renames renames"; git -C "$d" status --short | head -n 5; tail -n 5 "$d.log"; }
    has "$d.log" "git mv" && pass "$impl: the log says git mv" || bad "$impl: the tracked-migration log does not say git mv"

    # --- --dry-run on an older install changes nothing --------------------------------------
    d="$t/$impl-dry"; legacy "$d"
    printf '.toolkit/.local/\n' > "$d/.gitignore"
    git -C "$d" init -q && git -C "$d" add -A && git -C "$d" -c user.name=t -c user.email=t@example.invalid commit -qm seed
    printf 'scratch\n' > "$d/untracked.txt"
    before=$(git -C "$d" status --porcelain -uall); before_files=$(snapshot "$d")
    status=0; upd "$impl" "$d" .toolkit --dry-run > "$d.log" 2>&1 || status=$?
    after=$(git -C "$d" status --porcelain -uall); after_files=$(snapshot "$d")
    [ "$status" -eq 0 ] && [ "$before" = "$after" ] && [ "$before_files" = "$after_files" ] \
      && pass "$impl: --dry-run leaves git status and every byte as they were" || { bad "$impl: --dry-run changed the tree (exit $status)"; tail -n 5 "$d.log"; }
    has "$d.log" "would move .toolkit/ to .mskit/" && has "$d.log" "would rewrite" \
      && pass "$impl: --dry-run says what the migration would do" || { bad "$impl: --dry-run does not announce the migration"; tail -n 8 "$d.log"; }
  else
    echo "SKIP  update dir: $impl tracked migration and dry run (no git)"
  fi

  # --- both folders present ------------------------------------------------------------------
  d="$t/$impl-both"; legacy "$d"
  mkdir -p "$d/.mskit"; printf '{\n  "kitDir": ".mskit"\n}\n' > "$d/.mskit/kit.json"
  before=$(snapshot "$d")
  status=0; upd "$impl" "$d" .toolkit > "$d.log" 2>&1 || status=$?
  [ "$status" -ne 0 ] && has "$d.log" ".toolkit/" && has "$d.log" ".mskit/" && [ "$before" = "$(snapshot "$d")" ] \
    && pass "$impl: .toolkit/ beside .mskit/ is refused and nothing changes" || { bad "$impl: both folders: exit $status"; tail -n 3 "$d.log"; }

  # --- an explicit --kit-dir .toolkit keeps the old folder -----------------------------------
  d="$t/$impl-keep"; legacy "$d"
  status=0; upd "$impl" "$d" .toolkit --kit-dir .toolkit > "$d.log" 2>&1 || status=$?
  [ "$status" -eq 0 ] && [ ! -e "$d/.mskit" ] && [ "$(kitdir_of "$d/.toolkit/kit.json")" = ".toolkit" ] \
    && pass "$impl: --kit-dir .toolkit keeps the older folder and records it" || { bad "$impl: --kit-dir .toolkit: exit $status"; tail -n 3 "$d.log"; }

  # --- 0.3.0 stopped after the move: the kit is in .mskit/, Directory.Build.* import .toolkit/ ---
  d="$t/$impl-heal"; legacy "$d"
  mv "$d/.toolkit" "$d/.mskit"
  printf 'bin/\n.toolkit/msbuild/local/\nmy.toolkit/\n' > "$d/.gitignore"
  mkdir -p "$d/.github"
  printf 'version: 2\nupdates:\n  - package-ecosystem: nuget\n    directory: "/"\n    ignore-paths:\n      - .toolkit/**\n' > "$d/.github/dependabot.yml"
  status=0; upd "$impl" "$d" .mskit --dry-run > "$d.dry.log" 2>&1 || status=$?
  [ "$status" -eq 0 ] && has "$d.dry.log" "would rewrite" && has "$d/Directory.Build.props" .toolkit \
    && pass "$impl: --dry-run on a half-moved kit says what it would rewrite and changes nothing" || { bad "$impl: dry run of the repair: exit $status"; tail -n 5 "$d.dry.log"; }
  status=0; upd "$impl" "$d" .mskit > "$d.log" 2>&1 || status=$?
  [ "$status" -eq 0 ] && [ "$(kitdir_of "$d/.mskit/kit.json")" = ".mskit" ] && [ ! -e "$d/.toolkit" ] \
    && has "$d/Directory.Build.props" '$(MSBuildThisFileDirectory).mskit/msbuild/init.props' && ! has "$d/Directory.Build.props" .toolkit \
    && has "$d/Directory.Build.targets" '$(MSBuildThisFileDirectory).mskit\msbuild\init.targets' && ! has "$d/Directory.Build.targets" .toolkit \
    && pass "$impl: one more run repairs Directory.Build.* of a half-moved kit" || { bad "$impl: repair of a half-moved kit: exit $status"; tail -n 8 "$d.log"; }
  if [ "$(tr -d '\r' < "$d/.gitignore")" = "$(printf 'bin/\n.mskit/msbuild/local/\nmy.toolkit/')" ] && has "$d/.github/dependabot.yml" '- .mskit/**' \
    && has "$d.log" "rewrote" && ! has "$d.log" "add to Directory.Build"; then pass "$impl: the repair rewrites .gitignore and dependabot.yml and says so"
  else bad "$impl: the repair: .gitignore $(tr '\n' '|' < "$d/.gitignore"), log:"; tail -n 8 "$d.log"; fi

  d="$t/$impl-no-heal"; mkdir -p "$d"
  upd "$impl" "$d" kit > "$d.seed.log" 2>&1 || true
  printf '.toolkit/\n' > "$d/.gitignore"
  status=0; upd "$impl" "$d" .mskit > "$d.log" 2>&1 || status=$?
  [ "$status" -eq 0 ] && [ "$(tr -d '\r' < "$d/.gitignore")" = ".toolkit/" ] && ! has "$d.log" "rewrote" \
    && pass "$impl: a kit already imported from .mskit/ leaves other .toolkit names alone" || { bad "$impl: an unrelated .toolkit name: exit $status, .gitignore $(cat "$d/.gitignore")"; tail -n 5 "$d.log"; }

  # --- a reference that cannot be rewritten stops the run --------------------------------------
  d="$t/$impl-readonly"; legacy "$d"
  chmod a-w "$d/Directory.Build.props"
  if [ -w "$d/Directory.Build.props" ]; then
    echo "SKIP  update dir: $impl read-only Directory.Build.props (this user writes read-only files)"
  else
    status=0; upd "$impl" "$d" .toolkit > "$d.log" 2>&1 || status=$?
    [ "$status" -ne 0 ] && has "$d.log" "cannot write Directory.Build.props" && ! has "$d.log" "done: DragoAnt.MSBuildKit" \
      && pass "$impl: a Directory.Build.props it cannot write fails the run and names the file" || { bad "$impl: read-only Directory.Build.props: exit $status"; tail -n 5 "$d.log"; }
  fi
  chmod u+w "$d/Directory.Build.props"
done

# --- 0.2.1 -> this kit: the old updater installs, the new one it copied moves the folder ------
if git -C "$here" rev-parse -q --verify 'refs/tags/v0.2.1^{commit}' > /dev/null 2>&1; then
  mkdir -p "$t/v021"
  git -C "$here" archive v0.2.1 kit | tar -x -C "$t/v021"
  for impl in $impls; do
    d="$t/$impl-from-021"; mkdir -p "$d"
    if [ "$impl" = sh ]; then
      sh "$t/v021/kit/.toolkit/update.sh" --source "$t/v021/kit" --root "$d" > "$d.seed.log" 2>&1
      run() { (cd "$d" && sh .toolkit/update.sh --source "$kit"); }
      script=update.sh
    else
      (cd "$d" && pwsh -NoProfile -NonInteractive -File "$t/v021/kit/.toolkit/update.ps1" -Source "$t/v021/kit") > "$d.seed.log" 2>&1
      run() { (cd "$d" && pwsh -NoProfile -NonInteractive -File .toolkit/update.ps1 -Source "$kit"); }
      script=update.ps1
    fi
    cmp -s "$d/.toolkit/$script" "$t/v021/kit/.toolkit/$script" && pass "$impl: v0.2.1 installed .toolkit/ with its own $script" || bad "$impl: v0.2.1 seed (see $d.seed.log)"
    status=0; run > "$d.run1.log" 2>&1 || status=$?
    [ "$status" -eq 0 ] && [ -d "$d/.toolkit/msbuild" ] && [ ! -e "$d/.mskit" ] && cmp -s "$d/.toolkit/$script" "$kit/.toolkit/$script" \
      && pass "$impl: run 1 (the 0.2.1 $script) installs into .toolkit/ and copies the new $script" || { bad "$impl: run 1 from 0.2.1: exit $status"; tail -n 5 "$d.run1.log"; }
    status=0; run > "$d.run2.log" 2>&1 || status=$?
    [ "$status" -eq 0 ] && [ -f "$d/.mskit/kit.json" ] && [ ! -e "$d/.toolkit" ] \
      && has "$d/Directory.Build.props" '$(MSBuildThisFileDirectory).mskit/msbuild/init.props' \
      && pass "$impl: run 2 (the new $script) moves the kit to .mskit/" || { bad "$impl: run 2 from 0.2.1: exit $status"; tail -n 8 "$d.run2.log"; }
  done

  # --- the consumer's path: a tracked repo, run 2 without --source or --version downloads ------
  if command -v git > /dev/null 2>&1; then
    sh "$here/tools/pack-kit.sh" 9.9.9 "$t/releases/v9.9.9" > "$t/pack.log" 2>&1 || { bad "pack-kit.sh 9.9.9"; cat "$t/pack.log"; }
    mkdir -p "$t/fake-curl" "$t/term-git"
    cat > "$t/fake-curl/curl" <<EOF
#!/bin/sh
out=""; url=""
while [ \$# -gt 0 ]; do case "\$1" in -o) out="\$2"; shift 2 ;; -*) shift ;; *) url="\$1"; shift ;; esac; done
case "\$url" in https://github.com/*/releases/download/*) f="$t/releases/\${url##*/releases/download/}" ;; *) exit 22 ;; esac
[ -f "\$f" ] || exit 22
cp "\$f" "\$out"
EOF
    cat > "$t/term-git/git" <<EOF
#!/bin/sh
for a in "\$@"; do [ "\$a" = mv ] && kill -TERM \$PPID; done
exec "$(command -v git)" "\$@"
EOF
    chmod +x "$t/fake-curl/curl" "$t/term-git/git"
    consumer() {
      d="$1"; rm -rf "$d"; mkdir -p "$d/.github"
      sh "$t/v021/kit/.toolkit/update.sh" --source "$t/v021/kit" --root "$d" > "$d.seed.log" 2>&1
      printf 'bin/\n.toolkit/msbuild/local/\n' > "$d/.gitignore"
      printf 'version: 2\nupdates:\n  - package-ecosystem: nuget\n    directory: "/"\n    ignore-paths:\n      - .toolkit/**\n' > "$d/.github/dependabot.yml"
      git -C "$d" init -q && git -C "$d" add -A && git -C "$d" -c user.name=t -c user.email=t@example.invalid commit -qm seed
      (cd "$d" && sh .toolkit/update.sh --source "$kit" --version 9.9.9) > "$d.run1.log" 2>&1
    }
    moved() {
      [ ! -e "$1/.toolkit" ] && [ "$(kitdir_of "$1/.mskit/kit.json")" = ".mskit" ] \
        && has "$1/Directory.Build.props" '$(MSBuildThisFileDirectory).mskit/msbuild/init.props' && ! has "$1/Directory.Build.props" .toolkit \
        && has "$1/Directory.Build.targets" '$(MSBuildThisFileDirectory).mskit/msbuild/init.targets' && ! has "$1/Directory.Build.targets" .toolkit \
        && has "$1/.github/dependabot.yml" '- .mskit/**'
    }

    d="$t/sh-download"; consumer "$d"
    status=0; (cd "$d" && PATH="$t/fake-curl:$PATH" sh .toolkit/update.sh) > "$d.run2.log" 2>&1 || status=$?
    [ "$status" -eq 0 ] && has "$d.run2.log" "downloading" && has "$d.run2.log" "(git mv)" && moved "$d" \
      && pass "sh: run 2 from .toolkit/ without --version downloads, moves the kit and rewrites the imports" || { bad "sh: run 2 that downloads: exit $status"; tail -n 8 "$d.run2.log"; }

    d="$t/sh-download-term"; consumer "$d"
    status=0; (cd "$d" && PATH="$t/term-git:$t/fake-curl:$PATH" sh .toolkit/update.sh) > "$d.run2.log" 2>&1 || status=$?
    [ "$status" -ne 0 ] && has "$d.run2.log" "stopped by SIGTERM" && ! has "$d.run2.log" "No such file" \
      && pass "sh: a run stopped by SIGTERM during the move exits $status and says to run it again" || { bad "sh: SIGTERM during the move: exit $status"; tail -n 8 "$d.run2.log"; }
    status=0; (cd "$d" && PATH="$t/fake-curl:$PATH" sh .mskit/update.sh) > "$d.run3.log" 2>&1 || status=$?
    [ "$status" -eq 0 ] && moved "$d" \
      && pass "sh: the next run finishes the stopped move" || { bad "sh: the run after SIGTERM: exit $status"; tail -n 8 "$d.run3.log"; }
  else
    echo "SKIP  update dir: the download path (no git)"
  fi
else
  echo "SKIP  update dir: the 0.2.1 upgrade (no v0.2.1 tag; fetch the tags)"
fi

echo
if [ "$failures" -eq 0 ]; then echo "update dir: all checks passed"; else echo "update dir: $failures failure(s)"; exit 1; fi

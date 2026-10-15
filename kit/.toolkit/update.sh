#!/bin/sh
# Installs or updates DragoAnt.MSBuildKit in a repository's kit folder (default .mskit/).
# Usage: sh .mskit/update.sh [--version X.Y.Z] [--add PART] [--remove PART] [--dry-run] [--kit-dir NAME]
#        [--source DIR|ZIP] [--sha256 HEX] [--repo OWNER/NAME] [--root DIR]

# One brace group, parsed in full before it runs: the update may replace this file while it runs.
{
set -eu

# Started from a .toolkit/ folder, run from a copy: Windows refuses to move a folder holding an open file.
self_copy=""
if [ "${1:-}" = "--from-copy" ]; then
  self_copy=$(dirname "$0"); shift
else
  case "$(dirname "$0")" in
    .toolkit|*/.toolkit|*\\.toolkit)
      self_copy=$(mktemp -d)
      cp "$0" "$self_copy/update.sh"
      exec sh "$self_copy/update.sh" --from-copy "$@" ;;
  esac
fi

repo="DragoAnt/MSBuildKit"
version=""
source=""
expected_sha=""
root=""
dry_run=0
add_parts=""
remove_parts=""
kit_name=""
legacy_name=".toolkit"

usage() {
  sed -n '2,4p' "$0" | sed 's/^# \{0,1\}//'
  cat <<'EOF'

  --version X.Y.Z   kit version to install (default: the version in kit.json, else the latest release)
  --add PART        install an optional part (repeatable), e.g. --add PackageAsProj
  --remove PART     uninstall an optional part (repeatable)
  --dry-run         show what would change and change nothing
  --kit-dir NAME    kit folder in the repository root (default: the folder whose kit.json names it, else .mskit);
                    an older .toolkit/ install moves there
  --source DIR|ZIP  install from a local kit build instead of a GitHub release
  --sha256 HEX      expected SHA-256 of the release zip (or of a --source zip)
  --repo OWNER/NAME GitHub repository to download releases from (default: DragoAnt/MSBuildKit)
  --root DIR        repository root (default: the current folder)
EOF
}

fail() { echo "update: error: $*" >&2; exit 1; }
say() { echo "update: $*"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --version) [ $# -ge 2 ] || fail "--version needs a value"; version="${2#v}"; shift 2 ;;
    --source) [ $# -ge 2 ] || fail "--source needs a value"; source="$2"; shift 2 ;;
    --sha256) [ $# -ge 2 ] || fail "--sha256 needs a value"; expected_sha=$(printf '%s' "$2" | tr 'A-F' 'a-f'); shift 2 ;;
    --repo) [ $# -ge 2 ] || fail "--repo needs a value"; repo="$2"; shift 2 ;;
    --root) [ $# -ge 2 ] || fail "--root needs a value"; root="$2"; shift 2 ;;
    --add) [ $# -ge 2 ] || fail "--add needs a value"; add_parts="$add_parts $2"; shift 2 ;;
    --remove) [ $# -ge 2 ] || fail "--remove needs a value"; remove_parts="$remove_parts $2"; shift 2 ;;
    --dry-run) dry_run=1; shift ;;
    --kit-dir) [ $# -ge 2 ] || fail "--kit-dir needs a value"; kit_name="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown argument '$1' (see --help)" ;;
  esac
done

[ -n "$root" ] || root=$(pwd)
[ -d "$root" ] || fail "root '$root' is not a directory"

kitdir_in() { [ -f "$1" ] && sed -n 's/.*"kitDir"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$1" | head -n 1 || true; }
if [ -n "$kit_name" ]; then
  case "$kit_name" in
    .|..|*/*|*\\*|*:*) fail "--kit-dir '$kit_name' must be the name of a folder in the repository root" ;;
  esac
else
  count=0; claimed=""
  for j in "$root"/*/kit.json "$root"/.[!.]*/kit.json; do
    [ -f "$j" ] || continue
    d=$(basename "$(dirname "$j")")
    if [ "$(kitdir_in "$j")" = "$d" ]; then count=$((count+1)); kit_name="$d"; claimed="$claimed $d/"; fi
  done
  [ "$count" -le 1 ] || fail "more than one kit folder:$claimed; pass --kit-dir NAME"
  [ -n "$kit_name" ] || kit_name=".mskit"
fi
toolkit="$root/$kit_name"
kit_json="$toolkit/kit.json"
legacy="$root/$legacy_name"
migrate=0
if [ "$kit_name" != "$legacy_name" ] && { [ -f "$legacy/kit.json" ] || [ -f "$legacy/msbuild/init.props" ]; } && [ -z "$(kitdir_in "$legacy/kit.json")" ]; then
  [ ! -e "$toolkit" ] || fail "both $legacy_name/ (an older install) and $kit_name/ exist; remove the one you do not use, or pass --kit-dir $legacy_name to keep the older folder"
  migrate=1
  kit_json="$legacy/kit.json"
fi
current="$toolkit"
[ "$migrate" -eq 0 ] || current="$legacy"

json_value() { [ -f "$kit_json" ] && sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$kit_json" | head -n 1 || true; }
json_parts() { [ -f "$kit_json" ] && sed -n 's/.*"parts"[[:space:]]*:[[:space:]]*\[\(.*\)\].*/\1/p' "$kit_json" | tr -d '" ' | tr ',' ' ' || true; }

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1
  else fail "neither sha256sum nor shasum is available"; fi
}

download() {
  if command -v curl >/dev/null 2>&1; then curl -fsSL --retry 3 -o "$2" "$1"
  elif command -v wget >/dev/null 2>&1; then wget -q -O "$2" "$1"
  else fail "neither curl nor wget is available"; fi
}

extract_zip() {
  if command -v unzip >/dev/null 2>&1; then unzip -q -o "$1" -d "$2"
  else tar -xf "$1" -C "$2" || fail "cannot extract '$1': install unzip"; fi
}

work=$(mktemp -d)
trap 'rm -rf "$work"; if [ -n "$self_copy" ]; then rm -f "$self_copy/update.sh"; rmdir "$self_copy" 2>/dev/null || true; fi' EXIT
# A signal trap that returns lets the script go on without $work, so a signal ends the run.
stopped() { echo "update: error: stopped by $1 before the update finished; run the same command again to finish it" >&2; exit "$2"; }
trap 'stopped SIGHUP 129' HUP
trap 'stopped SIGINT 130' INT
trap 'stopped SIGTERM 143' TERM
kit_dir=""
actual_sha=""

[ -n "$repo" ] || fail "--repo is empty"
recorded_repo=$(json_value repository)
if [ -n "$recorded_repo" ] && [ "$repo" = "DragoAnt/MSBuildKit" ]; then repo="$recorded_repo"; fi

if [ -n "$source" ]; then
  if [ -d "$source" ]; then
    [ -f "$source/.toolkit/msbuild/init.props" ] || fail "'$source' is not a kit build: no .toolkit/msbuild/init.props"
    kit_dir="$source"
  elif [ -f "$source" ]; then
    actual_sha=$(sha256_of "$source")
    if [ -n "$expected_sha" ] && [ "$actual_sha" != "$expected_sha" ]; then
      fail "SHA-256 mismatch for '$source': expected $expected_sha, got $actual_sha"
    fi
    mkdir -p "$work/kit"; extract_zip "$source" "$work/kit"; kit_dir="$work/kit"
  else
    fail "--source '$source' does not exist"
  fi
  [ -n "$version" ] || version=$(sed -n '1p' "$kit_dir/.toolkit/kit.version" 2>/dev/null || true)
  [ -n "$version" ] || version="0.0.0-local"
else
  [ -n "$version" ] || version=$(json_value version)
  if [ -z "$version" ]; then
    download "https://api.github.com/repos/$repo/releases/latest" "$work/latest.json" || fail "cannot query the latest release of $repo"
    tag=$(sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$work/latest.json" | head -n 1)
    [ -n "$tag" ] || fail "no release found in $repo"
    version="${tag#v}"
  fi
  zip_name="msbuildkit-$version.zip"
  base="https://github.com/$repo/releases/download/v$version"
  say "downloading $base/$zip_name"
  download "$base/$zip_name" "$work/$zip_name" || fail "cannot download $base/$zip_name"
  download "$base/$zip_name.sha256" "$work/$zip_name.sha256" || fail "cannot download $base/$zip_name.sha256"
  published_sha=$(cut -d' ' -f1 "$work/$zip_name.sha256" | tr 'A-F' 'a-f')
  actual_sha=$(sha256_of "$work/$zip_name")
  [ "$actual_sha" = "$published_sha" ] || fail "SHA-256 mismatch for $zip_name: published $published_sha, downloaded $actual_sha"
  pinned_sha=$(json_value sha256)
  if [ -z "$expected_sha" ] && [ "$(json_value version)" = "$version" ] && [ -n "$pinned_sha" ]; then expected_sha="$pinned_sha"; fi
  if [ -n "$expected_sha" ] && [ "$actual_sha" != "$expected_sha" ]; then
    fail "SHA-256 mismatch for $zip_name: expected $expected_sha (kit.json or --sha256), got $actual_sha"
  fi
  mkdir -p "$work/kit"; extract_zip "$work/$zip_name" "$work/kit"; kit_dir="$work/kit"
fi

new_toolkit="$kit_dir/.toolkit"
[ -f "$new_toolkit/msbuild/init.props" ] || fail "the kit build has no .toolkit/msbuild/init.props"
[ -f "$new_toolkit/kit.parts" ] || fail "the kit build has no .toolkit/kit.parts"
if [ -d "$current" ] && [ "$(cd "$new_toolkit" && pwd -P)" = "$(cd "$current" && pwd -P)" ]; then fail "the target $(basename "$current")/ is the kit source itself; run from the repository you want to update, or pass --root"; fi
parts_file="$work/kit.parts"
tr -d '\r' < "$new_toolkit/kit.parts" | grep -v '^[[:space:]]*#' | grep -v '^[[:space:]]*$' > "$parts_file"

part_kind() { awk -v p="$1" '$1==p {print $2}' "$parts_file"; }
part_deps() { awk -v p="$1" '$1==p {for (i=3;i<=NF;i++) print $i}' "$parts_file"; }
part_dir() { if [ "$1" = "Trunk" ]; then echo "DragoAnt.MSBuildKit"; else echo "DragoAnt.MSBuildKit.$1"; fi; }

optional=""
for p in $(json_parts) $add_parts; do
  kind=$(part_kind "$p")
  [ -n "$kind" ] || fail "unknown part '$p'; known parts: $(awk '{print $1}' "$parts_file" | tr '\n' ' ')"
  case " $optional " in *" $p "*) ;; *) if [ "$kind" = optional ]; then optional="$optional $p"; fi ;; esac
done
for p in $remove_parts; do
  kind=$(part_kind "$p")
  [ -n "$kind" ] || fail "unknown part '$p'"
  [ "$kind" = optional ] || fail "'$p' is a default part and cannot be removed"
  optional=$(echo " $optional " | sed "s/ $p / /g")
done

selected=$(awk '$2=="default" {print $1}' "$parts_file")
pending="$optional"
while [ -n "$(echo $pending)" ]; do
  next=""
  for p in $pending; do
    case " $(echo $selected) " in *" $p "*) continue ;; esac
    selected="$selected $p"
    for d in $(part_deps "$p"); do next="$next $d"; done
  done
  pending="$next"
done
recorded=""
for p in $selected; do if [ "$(part_kind "$p")" = optional ]; then recorded="$recorded $p"; fi; done
recorded=$(echo $recorded)

stage="$work/stage"
mkdir -p "$stage/msbuild"
for f in "$new_toolkit"/msbuild/*; do [ -f "$f" ] && cp "$f" "$stage/msbuild/"; done
for p in $selected; do
  d=$(part_dir "$p")
  [ -d "$new_toolkit/msbuild/$d" ] || fail "the kit build has no part folder msbuild/$d"
  cp -R "$new_toolkit/msbuild/$d" "$stage/msbuild/$d"
done

old_version=$(json_value version)
say "kit $repo ${old_version:-none} -> $version${actual_sha:+ (sha256 $actual_sha)}"
say "parts: $(echo $selected)"
changes=0
if [ -d "$current/msbuild" ]; then
  (cd "$current/msbuild" && find . -type f | sort) > "$work/old.lst"
else
  : > "$work/old.lst"
fi
(cd "$stage/msbuild" && find . -type f | sort) > "$work/new.lst"
for f in $(comm -13 "$work/old.lst" "$work/new.lst"); do say "  add    $kit_name/msbuild/${f#./}"; changes=$((changes+1)); done
for f in $(comm -23 "$work/old.lst" "$work/new.lst"); do say "  remove $kit_name/msbuild/${f#./}"; changes=$((changes+1)); done
for f in $(comm -12 "$work/old.lst" "$work/new.lst"); do
  cmp -s "$current/msbuild/$f" "$stage/msbuild/$f" || { say "  change $kit_name/msbuild/${f#./}"; changes=$((changes+1)); }
done

# Renames .toolkit only as a whole path segment, never inside a longer name; "dry" only reports.
rewrite_refs() {
  for f in Directory.Build.props Directory.Build.targets .gitignore .github/dependabot.yml; do
    [ -f "$root/$f" ] || continue
    awk -v old="$legacy_name" -v new="$kit_name" '
      function edge(c, set) { return c == "" || index(set, c) > 0 }
      {
        line = $0; out = ""
        while ((i = index(line, old)) > 0) {
          prev = i > 1 ? substr(line, i - 1, 1) : substr(out, length(out), 1)
          after = substr(line, i + length(old), 1)
          if (edge(prev, "/\\ \t\"\047()=,;") && edge(after, "/\\ \t\"\047\r*")) out = out substr(line, 1, i - 1) new
          else out = out substr(line, 1, i - 1 + length(old))
          line = substr(line, i + length(old))
        }
        print out line
      }' "$root/$f" > "$work/rewrite" || fail "cannot rewrite $legacy_name -> $kit_name in $f; run the update again"
    cmp -s "$root/$f" "$work/rewrite" && continue
    if [ "${1:-}" = dry ]; then say "  would rewrite $legacy_name -> $kit_name in $f"
    else
      cat "$work/rewrite" > "$root/$f" || fail "cannot write $f; make it writable and run the update again"
      say "rewrote $legacy_name -> $kit_name in $f"
    fi
  done
}

# An earlier run that stopped after the move left Directory.Build.* importing the old folder.
imports_legacy() {
  grep -qE '(^|[[:space:]/\\"'"'"'(=,;])\.toolkit[/\\]msbuild[/\\]init\.(props|targets)' "$root/Directory.Build.props" "$root/Directory.Build.targets" 2>/dev/null
}
heal=0
if [ "$migrate" -eq 0 ] && [ "$kit_name" != "$legacy_name" ] && [ ! -e "$legacy" ] && imports_legacy; then heal=1; fi

dbp="$root/Directory.Build.props"
dbt="$root/Directory.Build.targets"

if [ "$dry_run" -eq 1 ]; then
  if [ "$migrate" -eq 1 ]; then say "would move $legacy_name/ to $kit_name/"; rewrite_refs dry; fi
  if [ "$heal" -eq 1 ]; then say "Directory.Build.* still import $legacy_name/, the kit is in $kit_name/"; rewrite_refs dry; fi
  say "$changes file(s) under $kit_name/msbuild would change"
  [ -f "$dbp" ] || say "  would create Directory.Build.props"
  [ -f "$dbt" ] || say "  would create Directory.Build.targets"
  say "dry run: nothing changed"
  exit 0
fi

if [ "$migrate" -eq 1 ]; then
  if git -C "$root" rev-parse --is-inside-work-tree > /dev/null 2>&1 && [ -n "$(git -C "$root" ls-files -- "$legacy_name" 2>/dev/null)" ]; then
    git -C "$root" mv "$legacy_name" "$kit_name" || fail "git mv $legacy_name $kit_name failed"
    say "moved $legacy_name/ to $kit_name/ (git mv)"
  else
    mv "$legacy" "$toolkit" || fail "cannot move $legacy_name/ to $kit_name/"
    say "moved $legacy_name/ to $kit_name/"
  fi
  kit_json="$toolkit/kit.json"
  rewrite_refs
elif [ "$heal" -eq 1 ]; then
  say "Directory.Build.* still import $legacy_name/, the kit is in $kit_name/: finishing the move"
  rewrite_refs
fi

mkdir -p "$toolkit"
rm -rf "$toolkit/msbuild"
cp -R "$stage/msbuild" "$toolkit/msbuild"
if [ -d "$new_toolkit/res" ]; then mkdir -p "$toolkit/res"; cp -R "$new_toolkit/res/." "$toolkit/res/"; fi
cp "$new_toolkit/kit.parts" "$toolkit/kit.parts"
rm -f "$toolkit/kit.version"
say "$changes file(s) under $kit_name/msbuild changed"

parts_json=""
for p in $recorded; do parts_json="$parts_json${parts_json:+, }\"$p\""; done
printf '{\n  "repository": "%s",\n  "version": "%s",\n  "sha256": "%s",\n  "parts": [%s],\n  "kitDir": "%s"\n}\n' \
  "$repo" "$version" "$actual_sha" "$parts_json" "$kit_name" > "$kit_json"

for ext in props targets; do
  file="$root/Directory.Build.$ext"
  import="\$(MSBuildThisFileDirectory)$kit_name/msbuild/init.$ext"
  if [ ! -f "$file" ]; then
    printf '<Project>\n\n  <Import Project="%s" />\n\n</Project>\n' "$import" > "$file"
    say "created Directory.Build.$ext"
  elif ! grep -qF -e "$kit_name/msbuild/init.$ext" -e "$kit_name\\msbuild\\init.$ext" "$file"; then
    say "add to Directory.Build.$ext: <Import Project=\"$import\" />"
  fi
done
for f in update.ps1 update.sh; do if [ -f "$new_toolkit/$f" ]; then cp "$new_toolkit/$f" "$toolkit/$f"; fi; done
say "done: DragoAnt.MSBuildKit $version installed in $toolkit"
exit 0
}

#!/bin/sh
# Keeps the documentation honest against the kit: every property and item the kit defines has a row
# in docs/reference/properties.md, every code it reports a section headed by the code id in
# docs/reference/codes.md, every <Warning>/<Error> a HelpLink to that section, every MSKit_ name and
# code the docs mention exists in the kit, no file spells a code the old way, and every link resolves.
# Usage: sh tools/docs-check.sh [--root DIR] [--list properties|items|codes|diagnostics]
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
list=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root) [ $# -ge 2 ] || { echo "docs-check: --root needs a value" >&2; exit 2; }; root=$(cd "$2" && pwd); shift 2 ;;
    --list) [ $# -ge 2 ] || { echo "docs-check: --list needs a value" >&2; exit 2; }; list="$2"; shift 2 ;;
    -h|--help) sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "docs-check: unknown argument '$1'" >&2; exit 2 ;;
  esac
done
case "$list" in ""|properties|items|codes|diagnostics) ;; *) echo "docs-check: --list takes properties, items, codes or diagnostics" >&2; exit 2 ;; esac

[ -d "$root/kit/.toolkit/msbuild" ] || { echo "docs-check: no kit at $root/kit/.toolkit/msbuild" >&2; exit 2; }
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT INT TERM
cd "$root"

# Kit inventory with XML comments removed, one process for every file:
# "P <name> <where>" property set, "I" item, "R" property read, "C" diagnostic code,
# "W <where> <Code> <HelpLink>" a <Warning> or <Error> task ("-" for a missing attribute).
find kit/.toolkit/msbuild -type f \( -name '*.props' -o -name '*.targets' -o -name '*.cs.txt' \) -exec awk '
  FNR == 1 { incomment = 0; pg = 0; ig = 0; inel = 0 }
  { sub(/\r$/, "") }
  FILENAME ~ /\.cs\.txt$/ {
    rest = $0
    while (match(rest, /"MSKIT[A-Z]+[0-9][0-9][0-9]"/)) { print "C", substr(rest, RSTART + 1, RLENGTH - 2), FILENAME ":" FNR; rest = substr(rest, RSTART + RLENGTH) }
    next
  }
  {
    line = $0; out = ""
    while (line != "") {
      if (incomment) { e = index(line, "-->"); if (e == 0) break; line = substr(line, e + 3); incomment = 0 }
      else { s = index(line, "<!--"); if (s == 0) { out = out line; break }; out = out substr(line, 1, s - 1); line = substr(line, s + 4); incomment = 1 }
    }
    rest = out
    while (match(rest, /<\/?[A-Za-z_][A-Za-z0-9_.]*/)) {
      tag = substr(rest, RSTART + 1, RLENGTH - 1); rest = substr(rest, RSTART + RLENGTH)
      if (tag == "PropertyGroup") pg++
      else if (tag == "/PropertyGroup") pg--
      else if (tag == "ItemGroup") ig++
      else if (tag == "/ItemGroup") ig--
      else if (substr(tag, 1, 1) != "/" && pg > 0) print "P", tag, FILENAME ":" FNR
      else if (substr(tag, 1, 1) != "/" && ig > 0 && tag ~ /^MSKit_/) print "I", tag, FILENAME ":" FNR
    }
    rest = out
    while (match(rest, /\$\(MSKit_[A-Za-z0-9_]+/)) { print "R", substr(rest, RSTART + 2, RLENGTH - 2), FILENAME ":" FNR; rest = substr(rest, RSTART + RLENGTH) }
    rest = out
    while (match(rest, /MSKIT[A-Z]+[0-9][0-9][0-9]/)) { print "C", substr(rest, RSTART, RLENGTH), FILENAME ":" FNR; rest = substr(rest, RSTART + RLENGTH) }
    if (!inel && (match(out, /<(Warning|Error)[[:space:]\/>]/) || match(out, /<(Warning|Error)$/))) { inel = 1; el = substr(out, RSTART); elat = FILENAME ":" FNR }
    else if (inel) el = el " " out
    if (inel && (e = closed(el))) { el = substr(el, 1, e); print "W", elat, attr(el, "Code"), attr(el, "HelpLink"); inel = 0 }
  }
  function closed(s,   i, c, q) { for (i = 1; i <= length(s); i++) { c = substr(s, i, 1); if (c == "\"") q = !q; else if (c == ">" && !q) return i }; return 0 }
  function attr(s, name,   v) {
    if (!match(s, "[[:space:]]" name "=\"[^\"]*\"")) return "-"
    v = substr(s, RSTART, RLENGTH); sub(/^[[:space:]]*[A-Za-z]+="/, "", v); sub(/"$/, "", v)
    return v == "" ? "-" : v
  }' {} + > "$work/raw"

# Public names: MSKit_* (set or read) and Is* (set); never the kit's own _-prefixed state.
# Each is listed with the first place that sets it, else the first place that reads it.
awk -v dir="$work" '
  function better(a, b,   fa, fb, la, lb) {
    if (b == "") return 1
    fa = a; sub(/:[0-9]+$/, "", fa); fb = b; sub(/:[0-9]+$/, "", fb)
    la = a; sub(/^.*:/, "", la); lb = b; sub(/^.*:/, "", lb)
    return fa < fb || (fa == fb && la + 0 < lb + 0)
  }
  $1 == "W" { print $2 "\t" $3 "\t" $4 > (dir "/diagnostics"); next }
  $1 == "C" { if (better($3, c[$2])) c[$2] = $3; next }
  $1 == "I" { if (better($3, i[$2])) i[$2] = $3; next }
  $1 == "P" && ($2 ~ /^MSKit_/ || $2 ~ /^Is[A-Z]/) { if (better($3, set[$2])) set[$2] = $3; next }
  $1 == "R" { if (better($3, read[$2])) read[$2] = $3 }
  END {
    for (n in c) print n "\t" c[n] > (dir "/codes")
    for (n in i) print n "\t" i[n] > (dir "/items")
    for (n in set) print n "\t" set[n] "\t" (n in read ? "set, read" : "set") > (dir "/properties")
    for (n in read) if (!(n in set)) print n "\t" read[n] "\tread" > (dir "/properties")
  }' "$work/raw"
for k in properties items codes diagnostics; do touch "$work/$k"; sort -o "$work/$k" "$work/$k"; done

if [ -n "$list" ]; then cat "$work/$list"; exit 0; fi

# Codes are spelled MSKIT<FAMILY><nnn>. The old spelling, an underscore after the prefix (a code or a
# family), may appear only as "formerly `...`" in the code reference and in released changelog sections.
if [ -e .git ]; then git ls-files -co --exclude-standard
else find . \( -name .git -o -name bin -o -name obj -o -name dist -o -name .claude -o -name node_modules -o -name .toolkit \) -prune \
  -o -type f -print | sed 's|^\./||'; find kit/.toolkit -type f; fi > "$work/files"
released=$(grep -n '^## \[[0-9]' CHANGELOG.md 2>/dev/null | head -n 1 | cut -d: -f1)
tr '\n' '\0' < "$work/files" | xargs -0 grep -nI 'MSKIT[_]' /dev/null 2>/dev/null \
  | awk -v released="${released:-0}" '
      { sub(/\r$/, ""); p = index($0, ":"); f = substr($0, 1, p - 1); rest = substr($0, p + 1); p = index(rest, ":"); ln = substr(rest, 1, p - 1); text = substr(rest, p + 1) }
      f == "CHANGELOG.md" && released > 0 && ln + 0 >= released { next }
      f == "docs/reference/codes.md" { gsub(/formerly `MSKIT[_][A-Z]+[0-9][0-9][0-9]`/, "", text) }
      { while (match(text, /MSKIT[_][A-Z]*[0-9]*/)) { print f ":" ln "\t" substr(text, RSTART, RLENGTH); text = substr(text, RSTART + RLENGTH) } }' > "$work/oldspelling" || true

# Every Markdown file a reader sees, and every path in the repository for the link check.
{ for f in README.md CONTRIBUTING.md SECURITY.md; do [ -f "$f" ] && echo "$f"; done
  [ -d docs ] && find docs -type f -name '*.md' | sort; } > "$work/docs.lst"
find . \( -name .git -o -name bin -o -name obj -o -name dist -o -name .claude -o -name node_modules \) -prune -o -print \
  | sed 's|^\./||' > "$work/paths"

# One pass over the docs: reference rows, mentions, headings and links.
awk -v dir="$work" '
  FNR == 1 { fence = 0; f = FILENAME; d = f; if (!sub(/\/[^\/]*$/, "", d)) d = "" }
  { sub(/\r$/, "") }
  /^[[:space:]]*(```|~~~)/ { fence = !fence; mention(); next }
  { mention() }
  fence { next }
  /^#+[[:space:]]/ { h = $0; sub(/^#+[[:space:]]+/, "", h); sub(/[[:space:]]+#+[[:space:]]*$/, "", h); h = tolower(h); gsub(/[^a-z0-9 _-]/, "", h); gsub(/ /, "-", h); print "S\t" f "\t" h }
  f == "docs/reference/properties.md" && /^\|/ {
    split($0, cell, "|"); c = cell[2]
    while (match(c, /`[^`]+`/)) { print "D\t" f "\t" substr(c, RSTART + 1, RLENGTH - 2); c = substr(c, RSTART + RLENGTH) }
  }
  f == "docs/reference/codes.md" && /^#+[[:space:]]+`?MSKIT[_]?[A-Z]+[0-9][0-9][0-9]/ {
    match($0, /MSKIT[_]?[A-Z]+[0-9][0-9][0-9]/); c = substr($0, RSTART, RLENGTH)
    print (c ~ /^MSKIT[_]/ ? "U\t" f ":" FNR "\t" c : "D\t" f "\t" c)
  }
  { line = $0; gsub(/`[^`]*`/, "", line)
    while (match(line, /\]\([^) ]+\)/)) { print "L\t" f "\t" FNR "\t" d "\t" substr(line, RSTART + 2, RLENGTH - 3); line = substr(line, RSTART + RLENGTH) } }
  function mention(   rest, t) {
    if (f == "CHANGELOG.md") return
    rest = $0
    while (match(rest, /MSKit_[A-Za-z0-9_]+[*<]?/)) { t = substr(rest, RSTART, RLENGTH); rest = substr(rest, RSTART + RLENGTH); if (t !~ /[*<]$/) print "N\t" f ":" FNR "\t" t }
    rest = $0
    while (match(rest, /MSKIT[A-Z]+[0-9][0-9][0-9]/)) { t = substr(rest, RSTART, RLENGTH); rest = substr(rest, RSTART + RLENGTH); print "M\t" f ":" FNR "\t" t }
  }' $(cat "$work/docs.lst") > "$work/docs.tsv"

awk -v dir="$work" -F'\t' '
  function norm(p,   n, a, i, out, k, s) {
    n = split(p, a, "/"); k = 0
    for (i = 1; i <= n; i++) {
      if (a[i] == "" || a[i] == ".") continue
      if (a[i] == "..") { if (k > 0) k--; else return "/outside" } else s[++k] = a[i]
    }
    out = ""; for (i = 1; i <= k; i++) out = out (i > 1 ? "/" : "") s[i]
    return out
  }
  function problem(m) { print "docs-check: " m; problems++ }
  FILENAME == dir "/properties" || FILENAME == dir "/items" { known[$1] = $2; what[$1] = (FILENAME == dir "/items" ? "item" : "property"); order[++n] = $1; next }
  FILENAME == dir "/codes" { code[$1] = $2; corder[++nc] = $1; next }
  FILENAME == dir "/diagnostics" { dwhere[++nd] = $1; dcode[nd] = $2; dlink[nd] = $3; next }
  FILENAME == dir "/oldspelling" { o = $2; sub(/_/, "", o); problem($1 ": " $2 " is the old spelling of " o); next }
  FILENAME == dir "/paths" { exists[$0] = 1; next }
  $1 == "S" { slug[$2 "#" $3] = 1; next }
  $1 == "D" { if ($2 == "docs/reference/properties.md") documented[$3] = 1; else documentedCode[$3] = 1; next }
  $1 == "N" { if (!($3 in known)) problem($2 " mentions " $3 ", which the kit does not define or read"); next }
  $1 == "M" { if (!($3 in code)) problem($2 " mentions " $3 ", which the kit never reports"); next }
  $1 == "U" { problem($2 ": write the heading as " gensub_id($3) " so its anchor is the code id without the underscore"); next }
  function gensub_id(c) { sub(/_/, "", c); return c }
  $1 == "L" { links[++nl] = $0; next }
  END {
    for (i = 1; i <= n; i++) if (!(order[i] in documented)) problem(what[order[i]] " " order[i] " (" known[order[i]] ") has no row in docs/reference/properties.md")
    for (i = 1; i <= nc; i++) if (!(corder[i] in documentedCode)) problem("code " corder[i] " (" code[corder[i]] ") has no section in docs/reference/codes.md")
    for (i = 1; i <= nd; i++) {
      c = dcode[i]; h = dlink[i]
      if (c == "-") { problem(dwhere[i] ": a <Warning>/<Error> without a Code"); continue }
      if (c ~ /^MSKIT[A-Z]+[0-9][0-9][0-9]$/) { want = "$(MSKit_CodesHelpBaseUrl)#" tolower(c); anchor = tolower(c) }
      else if (c ~ /^%\([A-Za-z_][A-Za-z0-9_.]*\)$/) { want = "$(MSKit_CodesHelpBaseUrl)#$([System.String]::Copy(\047" c "\047).ToLowerInvariant())"; anchor = "" }
      else continue
      if (h == "-") problem(dwhere[i] ": " c " has no HelpLink; set HelpLink=\"" want "\"")
      else if (h != want) problem(dwhere[i] ": " c " has HelpLink=\"" h "\"; expected \"" want "\"")
      if (anchor != "" && !(("docs/reference/codes.md#" anchor) in slug)) problem(dwhere[i] ": HelpLink anchor #" anchor " has no heading in docs/reference/codes.md")
    }
    relative = 0
    for (i = 1; i <= nl; i++) {
      split(links[i], l, "\t"); src = l[2]; ln = l[3]; base = l[4]; target = l[5]
      if (target ~ /^(https?|mailto):/) continue
      relative++
      path = target; anchor = ""
      if (index(target, "#")) { path = substr(target, 1, index(target, "#") - 1); anchor = substr(target, index(target, "#") + 1) }
      if (path == "") dest = src
      else {
        if (path !~ /^\.\.?\//) problem(src ":" ln ": link " target " must start with ./ or ../")
        dest = norm((base == "" ? "" : base "/") path)
        if (!(dest in exists)) { problem(src ":" ln ": link " target " points at a missing file"); continue }
      }
      if (anchor != "" && dest ~ /\.md$/ && !((dest "#" anchor) in slug)) problem(src ":" ln ": link " target " names a heading that does not exist")
    }
    if (problems) { print "docs-check: " problems " problem(s)"; exit 1 }
    printf "docs-check: %d properties and items, %d codes documented, %d diagnostics with a HelpLink; %d relative links resolve\n", n, nc, nd, relative
  }' "$work/properties" "$work/items" "$work/codes" "$work/diagnostics" "$work/oldspelling" "$work/paths" "$work/docs.tsv"

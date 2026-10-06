#!/bin/sh
# Keeps the documentation honest against the kit: every property and item the kit defines has a row
# in docs/reference/properties.md, every code it reports a section headed by the code id in
# docs/reference/codes.md, every <Warning>/<Error> a HelpLink to that section, every code exactly one
# BuildDiagnosticDescriptor item in the part that reports it, with the title, description, family
# and severity of its section and the text of its task, every MSKit_ name and code the docs mention
# exists in the kit, no file spells a code the old way, and every link resolves.
# Usage: sh tools/docs-check.sh [--root DIR] [--list properties|items|codes|diagnostics|descriptors]
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
list=""
while [ $# -gt 0 ]; do
  case "$1" in
    --root) [ $# -ge 2 ] || { echo "docs-check: --root needs a value" >&2; exit 2; }; root=$(cd "$2" && pwd); shift 2 ;;
    --list) [ $# -ge 2 ] || { echo "docs-check: --list needs a value" >&2; exit 2; }; list="$2"; shift 2 ;;
    -h|--help) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "docs-check: unknown argument '$1'" >&2; exit 2 ;;
  esac
done
case "$list" in ""|properties|items|codes|diagnostics|descriptors) ;; *) echo "docs-check: --list takes properties, items, codes, diagnostics or descriptors" >&2; exit 2 ;; esac

[ -d "$root/kit/.toolkit/msbuild" ] || { echo "docs-check: no kit at $root/kit/.toolkit/msbuild" >&2; exit 2; }
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT INT TERM
cd "$root"

# Kit inventory with XML comments removed, one process for every file:
# "P <name> <where>" property set, "I" item, "R" property read, "C" diagnostic code,
# "W <where> <Code> <HelpLink>" a <Warning> or <Error> task ("-" for a missing attribute).
# Tab-separated, for the diagnostic catalog: "T <where> <Warning|Error> <Code> <Text>" the same task,
# "B <where> <code> <Title> <MessageFormat> <Description> <Category> <DefaultSeverity> <HelpLink>" a
# BuildDiagnosticDescriptor item, "F <where> <item> <code> <metadata> <value>" an item named after a
# code (what a task with a computed Code reports), "X <where> <Project>" an import and
# "Q <file> <name> <value>" a one-line private property (a task text kept in one).
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
    while (FILENAME !~ /diagnostic\.descriptors\.props$/ && match(rest, /MSKIT[A-Z]+[0-9][0-9][0-9]/)) { print "C", substr(rest, RSTART, RLENGTH), FILENAME ":" FNR; rest = substr(rest, RSTART + RLENGTH) }
    if (match(out, /<_MSKit_[A-Za-z0-9_]+>[^<]+<\/_MSKit_[A-Za-z0-9_]+>/)) {
      q = substr(out, RSTART + 1, RLENGTH - 1); name = substr(q, 1, index(q, ">") - 1); q = substr(q, index(q, ">") + 1); sub(/<\/.*$/, "", q)
      print "Q	" FILENAME "	" name "	" q
    }
    rest = out
    if (inel) { el = el " " rest; rest = "" }
    while (1) {
      if (!inel) { if (!match(rest, /<[A-Za-z_][A-Za-z0-9_.]*/)) break; el = substr(rest, RSTART); rest = ""; elat = FILENAME ":" FNR; inel = 1 }
      e = closed(el); if (!e) break
      rest = substr(el, e + 1); el = substr(el, 1, e); inel = 0; element(el, elat)
    }
  }
  function element(el, at,   tag, code, a, name) {
    match(el, /^<[A-Za-z_][A-Za-z0-9_.]*/); tag = substr(el, 2, RLENGTH - 1); code = attr(el, "Include")
    if (tag == "Warning" || tag == "Error") {
      print "W", at, attr(el, "Code"), attr(el, "HelpLink")
      print "T	" at "	" tag "	" attr(el, "Code") "	" attr(el, "Text")
    }
    else if (tag == "BuildDiagnosticDescriptor")
      print "B	" at "	" code "	" attr(el, "Title") "	" attr(el, "MessageFormat") "	" attr(el, "Description") "	" attr(el, "Category") "	" attr(el, "DefaultSeverity") "	" attr(el, "HelpLink")
    else if (tag == "Import") print "X	" at "	" attr(el, "Project")
    else if (code ~ /^MSKIT[A-Z]+[0-9][0-9][0-9]$/)
      while (match(el, /[[:space:]][A-Za-z_][A-Za-z0-9_]*="[^"]*"/)) {
        a = substr(el, RSTART + 1, RLENGTH - 2); el = substr(el, RSTART + RLENGTH); name = substr(a, 1, index(a, "=") - 1)
        print "F	" at "	" tag "	" code "	" name "	" substr(a, index(a, "=") + 2)
      }
  }
  function closed(s,   at, q, e) {
    at = 0
    while (1) {
      q = index(s, "\""); e = index(s, ">")
      if (!e) return 0
      if (!q || e < q) return at + e
      at += q; s = substr(s, q + 1); q = index(s, "\""); if (!q) return 0
      at += q; s = substr(s, q + 1)
    }
  }
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
  /^[TBFXQ]\t/ { print > (dir "/elements"); next }
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
touch "$work/elements"
awk -F'\t' '$1 == "B" { part = $2; sub(/^kit\/\.toolkit\/msbuild\//, "", part); if (!sub(/\/.*$/, "", part)) part = "-"; print $3 "\t" part "\t" $2 }' "$work/elements" > "$work/descriptors"
for k in properties items codes diagnostics descriptors; do touch "$work/$k"; sort -o "$work/$k" "$work/$k"; done

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
  f == "docs/reference/codes.md" && /^##[[:space:]]/ { family = $0; sub(/^##[[:space:]]+/, "", family); section = "" }
  f == "docs/reference/codes.md" && /^#+[[:space:]]+`?MSKIT[_]?[A-Z]+[0-9][0-9][0-9]/ {
    match($0, /MSKIT[_]?[A-Z]+[0-9][0-9][0-9]/); c = substr($0, RSTART, RLENGTH)
    print (c ~ /^MSKIT[_]/ ? "U\t" f ":" FNR "\t" c : "D\t" f "\t" c)
    section = c; print "K\t" c "\tfamily\t" family
  }
  f == "docs/reference/codes.md" && section != "" && /^\*\*.*\*\*$/ && !((section, "title") in sectionhas) {
    sectionhas[section, "title"] = 1; t = substr($0, 3, length($0) - 4); gsub(/`/, "", t); print "K\t" section "\ttitle\t" t
  }
  f == "docs/reference/codes.md" && section != "" && index($0, "`" section "`") == 1 && !((section, "lead") in sectionhas) {
    sectionhas[section, "lead"] = 1; print "K\t" section "\tlead\t" $0
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
  function fileof(w) { sub(/:[0-9]+$/, "", w); return w }
  function partof(w) { sub(/^kit\/\.toolkit\/msbuild\//, "", w); return sub(/\/.*$/, "", w) ? w : "" }
  function unxml(t) { gsub(/&lt;/, "<", t); gsub(/&gt;/, ">", t); gsub(/&quot;/, "\"", t); gsub(/&apos;/, "\047", t); gsub(/&amp;/, "\\&", t); return t }
  function squeeze(t) { gsub(/[[:space:]]+/, " ", t); sub(/^ /, "", t); sub(/ $/, "", t); return t }
  # A task text with every MSBuild expression as {}, and a message format with every {n} as {}.
  function skeleton(t,   res, ch, depth) {
    res = ""
    while (match(t, /[$@%]\(/)) {
      res = res substr(t, 1, RSTART - 1) "{}"; t = substr(t, RSTART + 1); depth = 0
      while (match(t, /[()]/)) { ch = substr(t, RSTART, 1); t = substr(t, RSTART + 1); if (ch == "(") depth++; else if (--depth == 0) break }
      if (depth) t = ""
    }
    return squeeze(unxml(res t))
  }
  function formatskeleton(t) { gsub(/[{][0-9]+[}]/, "\001", t); gsub(/[{][{]/, "{", t); gsub(/[}][}]/, "}", t); gsub(/\001/, "{}", t); return squeeze(unxml(t)) }
  # Markdown as the plain text a descriptor carries: no code ticks, no bold, a link as its text.
  function plain(t,   label) {
    gsub(/`/, "", t); gsub(/\*\*/, "", t)
    while (match(t, /\[[^]]*\]\([^)]*\)/)) { label = substr(t, RSTART + 1, RLENGTH - 1); label = substr(label, 1, index(label, "](") - 1); t = substr(t, 1, RSTART - 1) label substr(t, RSTART + RLENGTH) }
    return squeeze(t)
  }
  function unescape(t) { gsub(/%24/, "$", t); gsub(/%40/, "@", t); gsub(/%3[Bb]/, ";", t); gsub(/%25/, "%", t); return t }
  function reports(code, w, kind, text,   f) {
    f = fileof(w)
    if (!(code in rpart)) { rcode[++nr] = code; rwhere[code] = w }
    rpart[code] = rpart[code] "|" partof(f) "|"; rkind[code] = rkind[code] "|" kind "|"
    if (text ~ /^\$\(_MSKit_[A-Za-z0-9_]+\)$/ && ((f, substr(text, 3, length(text) - 3)) in private)) text = private[f, substr(text, 3, length(text) - 3)]
    rtext[code, ++rtexts[code]] = skeleton(text)
  }
  FILENAME == dir "/elements" {
    if ($1 == "T") { twhere[++nt] = $2; tkind[nt] = $3; tcode[nt] = $4; ttext[nt] = $5 }
    else if ($1 == "B") { bwhere[++nb] = $2; bcode[nb] = $3; btitle[nb] = $4; bformat[nb] = $5; bdescription[nb] = $6; bcategory[nb] = $7; bseverity[nb] = $8; blink[nb] = $9 }
    else if ($1 == "F") { finding[fileof($2), $3, $4, $5] = $6; if (!((fileof($2), $3, $4) in findingseen)) { findingseen[fileof($2), $3, $4] = 1; findingcodes[fileof($2), $3] = findingcodes[fileof($2), $3] " " $4 } }
    else if ($1 == "X") imports[fileof($2)] = imports[fileof($2)] "|" $3 "|"
    else if ($1 == "Q") private[$2, $3] = $4
    next
  }
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
  $1 == "K" { doc[$2, $3] = $4; next }
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
    # The diagnostic catalog: one BuildDiagnosticDescriptor per code, in the part that reports it.
    for (i = 1; i <= nt; i++) {
      c = tcode[i]; src = fileof(twhere[i])
      if (c ~ /^MSKIT[A-Z]+[0-9][0-9][0-9]$/) reports(c, twhere[i], tkind[i], ttext[i])
      else if (c ~ /^%\([A-Za-z_][A-Za-z0-9_]*\.Identity\)$/) {
        item = substr(c, 3, length(c) - 12)
        if (!((src, item) in findingcodes)) { problem(twhere[i] ": cannot tell which codes " c " reports; declare each as <" item " Include=\"MSKIT...\"> in the same file"); continue }
        nf = split(findingcodes[src, item], fc, " ")
        for (k = 1; k <= nf; k++) {
          text = ttext[i]
          while (match(text, "%\\(" item "\\.[A-Za-z_][A-Za-z0-9_]*\\)")) {
            meta = substr(text, RSTART + length(item) + 3, RLENGTH - length(item) - 4)
            text = substr(text, 1, RSTART - 1) (meta == "Identity" ? fc[k] : finding[src, item, fc[k], meta]) substr(text, RSTART + RLENGTH)
          }
          reports(fc[k], twhere[i], tkind[i], text)
        }
      }
    }
    for (i = 1; i <= nb; i++) {
      c = bcode[i]; w = bwhere[i]; src = fileof(w); p = partof(src)
      if (c !~ /^MSKIT[A-Z]+[0-9][0-9][0-9]$/) { problem(w ": a BuildDiagnosticDescriptor needs Include=\"MSKIT<FAMILY><nnn>\", not \"" c "\""); continue }
      if (src !~ /\/diagnostic\.descriptors\.props$/ || p == "") problem(w ": declare " c " in its part folder, in diagnostic.descriptors.props")
      if (c in described) { problem(w ": " c " already has a BuildDiagnosticDescriptor at " described[c]); continue }
      described[c] = w; descriptorpart[p] = src
      if (!(c in rpart)) { problem(w ": " c " has a BuildDiagnosticDescriptor, but no <Warning> or <Error> reports it"); continue }
      if (!index(rpart[c], "|" p "|")) { owner = rpart[c]; gsub(/\|\|/, ", ", owner); gsub(/\|/, "", owner); problem(w ": " c " is described in part " p ", but reported by " owner "; move the item there") }
      if (bseverity[i] != "Warning" && bseverity[i] != "Error") problem(w ": " c " has DefaultSeverity=\"" bseverity[i] "\"; use Warning or Error")
      else if (!index(rkind[c], "|" bseverity[i] "|")) problem(w ": " c " has DefaultSeverity=\"" bseverity[i] "\", but no <" bseverity[i] "> reports it")
      lead = doc[c, "lead"]
      if (!match(lead, /\) \((warning|error)[,)]/)) problem("docs/reference/codes.md: the " c " section does not open with `" c "` (formerly ...) (warning) or (error)")
      else if (tolower(bseverity[i]) != substr(lead, RSTART + 3, RLENGTH - 4)) problem(w ": " c " has DefaultSeverity=\"" bseverity[i] "\", but its section in docs/reference/codes.md says (" substr(lead, RSTART + 3, RLENGTH - 4) ")")
      if (blink[i] != "$(MSKit_CodesHelpBaseUrl)#" tolower(c)) problem(w ": " c " has HelpLink=\"" blink[i] "\"; expected \"$(MSKit_CodesHelpBaseUrl)#" tolower(c) "\", as its task sets")
      title = unescape(unxml(btitle[i]))
      if (btitle[i] == "-") problem(w ": " c " has no Title")
      else if (!((c, "title") in doc)) problem("docs/reference/codes.md: the " c " section has no **title** line; the descriptor says \"" title "\"")
      else if (title != doc[c, "title"]) problem(w ": " c " has Title=\"" title "\", but its section in docs/reference/codes.md is titled \"" doc[c, "title"] "\"")
      if (bcategory[i] != doc[c, "family"]) problem(w ": " c " has Category=\"" bcategory[i] "\", but its section in docs/reference/codes.md is under \"" doc[c, "family"] "\"")
      body = (index(lead, " — ") ? plain(substr(lead, index(lead, " — ") + length(" — "))) : ""); d = squeeze(unescape(unxml(bdescription[i])))
      if (bdescription[i] == "-") problem(w ": " c " has no Description")
      else if (tolower(substr(d, 1, 1)) != tolower(substr(body, 1, 1)) || substr(d, 2) != substr(body, 2, length(d) - 1) \
          || (length(d) < length(body) && (d !~ /\.$/ || substr(body, length(d) + 1, 1) != " ")))
        problem(w ": the Description of " c " is not the opening sentence(s) of its section in docs/reference/codes.md")
      ok = 0; for (k = 1; k <= rtexts[c]; k++) if (formatskeleton(bformat[i]) == rtext[c, k]) ok = 1
      if (bformat[i] == "-") problem(w ": " c " has no MessageFormat")
      else if (!ok) problem(w ": the MessageFormat of " c " is not the text its task reports, with {0}, {1}, ... for the runtime values; expected the shape \"" rtext[c, 1] "\"")
      if ((btitle[i] bformat[i] bdescription[i] bcategory[i]) ~ /[$@%]\(/) problem(w ": " c " has metadata MSBuild would expand; write $( as %24(, @( as %40( and %( as %25(")
    }
    for (i = 1; i <= nr; i++) if (!(rcode[i] in described)) {
      p = partof(fileof(rwhere[rcode[i]]))
      problem("code " rcode[i] " (" rwhere[rcode[i]] ") has no BuildDiagnosticDescriptor item; add one to kit/.toolkit/msbuild/" p "/diagnostic.descriptors.props")
    }
    for (p in descriptorpart) {
      if (!index(imports["kit/.toolkit/msbuild/" p "/init.props"], "diagnostic.descriptors.props|")) problem(descriptorpart[p] " is not imported by kit/.toolkit/msbuild/" p "/init.props")
      if (!index(imports["kit/.toolkit/msbuild/init.props"], ")" p "/init.props|")) problem("kit/.toolkit/msbuild/init.props does not import " p "/init.props, so the descriptors of " p " never load")
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
    printf "docs-check: %d properties and items, %d codes documented, %d diagnostics with a HelpLink, %d described in the catalog; %d relative links resolve\n", n, nc, nd, nb, relative
  }' "$work/properties" "$work/items" "$work/codes" "$work/diagnostics" "$work/elements" "$work/oldspelling" "$work/paths" "$work/docs.tsv"

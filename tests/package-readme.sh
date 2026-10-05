# Package readme generated from the repository README (MSKit_PackageReadmeFrom).
# Sourced by tests/run.sh: uses its pass, bad, $out, $here, $clean_env and $readme_fixture.

sha=0123456789abcdef0123456789abcdef01234567
rel=tests/fixtures/PackageReadme
rm -rf "$readme_fixture"/*/bin "$readme_fixture"/*/obj

rf_pack() {
  name="$1"; proj="$2"; shift 2
  rm -rf "$out/readme-$name"
  if $clean_env dotnet pack "$readme_fixture/$proj/$proj.csproj" -c Release -nologo -o "$out/readme-$name" \
      -p:MSKit_PackageChecksAsErrors=False "$@" > "$out/readme-$name.log" 2>&1; then
    nupkg=$(ls "$out/readme-$name"/*.nupkg | grep -v '\.snupkg$' | head -n 1)
    unzip -p "$nupkg" readme.md | tr -d '\r' > "$out/readme-$name.md"
  else
    bad "readme $name: pack failed (see $out/readme-$name.log)"; tail -n 20 "$out/readme-$name.log"
    : > "$out/readme-$name.md"
  fi
}
rf_has() { grep -qF -- "$2" "$out/readme-$1.md" && pass "readme $1 has $2" || bad "readme $1 lacks $2"; }
rf_hasnt() { grep -qF -- "$2" "$out/readme-$1.md" && bad "readme $1 still has $2" || pass "readme $1 has no $2"; }
rf_warns() { grep -q "warning $2" "$out/readme-$1.log" && pass "readme $1 warns $2" || bad "readme $1 does not warn $2 (see $out/readme-$1.log)"; }
rf_quiet() { grep -q "warning $2" "$out/readme-$1.log" && bad "readme $1 warns $2 (see $out/readme-$1.log)" || pass "readme $1 does not warn $2"; }
rf_count() {
  n=$(grep -cF -- "$2" "$out/readme-$1.md" || true)
  [ "$n" = "$3" ] && pass "readme $1 has $2 $3 time(s)" || bad "readme $1 has $2 $n time(s), expected $3"
}
generated="$readme_fixture/Observer/obj/Release/package.readme.md"

# Pack only: a build never writes the generated readme.
$clean_env dotnet build "$readme_fixture/Observer/Observer.csproj" -c Release -nologo > "$out/readme-build.log" 2>&1 \
  || { bad "readme fixture build (see $out/readme-build.log)"; tail -n 20 "$out/readme-build.log"; }
[ -f "$generated" ] && bad "dotnet build generated the package readme" || pass "dotnet build does not generate the package readme"

# GitHub
gh="-p:RepositoryUrl=https://github.com/DragoAnt/Fixture -p:RepositoryCommit=$sha"
rf_pack github Observer $gh
rf_has github "[the guide](https://github.com/DragoAnt/Fixture/blob/$sha/$rel/docs/guide.md)"
rf_has github "[the docs folder](https://github.com/DragoAnt/Fixture/tree/$sha/$rel/docs)"
rf_has github "[the licence](https://github.com/DragoAnt/Fixture/blob/$sha/LICENSE)"
rf_has github "![diagram](https://raw.githubusercontent.com/DragoAnt/Fixture/$sha/$rel/docs/diagram.png)"
rf_has github "[details](https://github.com/DragoAnt/Fixture/blob/$sha/$rel/docs/guide.md#masking)"
rf_has github "[guide-ref]: https://github.com/DragoAnt/Fixture/blob/$sha/$rel/docs/guide.md"
rf_has github "[install](#install)"
rf_has github "![badge](https://img.shields.io/badge/fixture-green)"
rf_has github "[Release notes](https://github.com/DragoAnt/Fixture/releases)"
rf_has github "[Issues](https://github.com/DragoAnt/Fixture/issues)"
rf_has github "OBSERVER-ONLY"
rf_hasnt github "HTTP-ONLY"
rf_hasnt github "CONTRIBUTOR-ONLY"
rf_hasnt github "nuget:only"
rf_hasnt github "<!-- /nuget:skip -->"
rf_has github '`[raw](./inline-code.md)`'
rf_has github "[fenced](./fenced.md)"
rf_has github "<!-- nuget:skip -->"
awk '/^## /{exit} /\[Release notes\]/{found=1} END{exit !found}' "$out/readme-github.md" \
  && pass "readme github: the release-notes link is in the overview" || bad "readme github: the release-notes link is not in the overview"
for code in MSKIT_PKG009 MSKIT_PKG012 MSKIT_PKG017 MSKIT_PKG020 MSKIT_PKG021 MSKIT_PKG022; do rf_quiet github $code; done

# Incremental: the same inputs leave the generated file alone; a new commit regenerates it.
stamp1=$(stat -c %Y "$generated" 2>/dev/null || echo none)
sleep 1
rf_pack github-again Observer $gh
stamp2=$(stat -c %Y "$generated" 2>/dev/null || echo none)
[ "$stamp1" != none ] && [ "$stamp1" = "$stamp2" ] && pass "an unchanged README is not regenerated" || bad "an unchanged README was regenerated ($stamp1 -> $stamp2)"
rf_pack github-commit Observer -p:RepositoryUrl=https://github.com/DragoAnt/Fixture -p:RepositoryCommit=fedcba9876543210fedcba9876543210fedcba98
rf_has github-commit "/blob/fedcba9876543210fedcba9876543210fedcba98/"

# Multi-package: each package keeps only its own nuget:only blocks.
rf_pack http Observer.Http $gh
rf_has http "HTTP-ONLY"
rf_hasnt http "OBSERVER-ONLY"
rf_has http "[the guide](https://github.com/DragoAnt/Fixture/blob/$sha/$rel/docs/guide.md)"

# Single package with an Overview that already links releases and issues: nothing is added.
rf_pack single Single $gh
rf_count single "](https://github.com/DragoAnt/Fixture/releases)" 1
rf_count single "](https://github.com/DragoAnt/Fixture/issues)" 1
rf_has single "![shot](https://raw.githubusercontent.com/DragoAnt/Fixture/$sha/$rel/Single/shot.png)"

# The commit and URL from Source Link when nothing is passed.
head_sha=$(git -C "$here" rev-parse HEAD)
rf_pack sourcelink Observer
rf_has sourcelink "/blob/$head_sha/$rel/docs/guide.md)"

# gitlab.com, nested group
gl="-p:RepositoryUrl=https://gitlab.com/dragoant/sub/fixture -p:RepositoryCommit=$sha"
rf_pack gitlab Observer $gl
rf_has gitlab "[the guide](https://gitlab.com/dragoant/sub/fixture/-/blob/$sha/$rel/docs/guide.md)"
rf_has gitlab "[the docs folder](https://gitlab.com/dragoant/sub/fixture/-/tree/$sha/$rel/docs)"
rf_has gitlab "![diagram](https://gitlab.com/dragoant/sub/fixture/-/raw/$sha/$rel/docs/diagram.png)"
rf_has gitlab "[Release notes](https://gitlab.com/dragoant/sub/fixture/-/releases)"
rf_has gitlab "[Issues](https://gitlab.com/dragoant/sub/fixture/-/issues)"
rf_quiet gitlab MSKIT_PKG021
rf_quiet gitlab MSKIT_PKG017

# Self-hosted GitLab recognised through SourceLinkGitLabHost: its raw images are not on nuget.org's list.
rf_pack gitlab-self Observer -p:RepositoryUrl=https://git.example.org/team/fixture -p:RepositoryCommit=$sha -p:FixtureGitLabHost=git.example.org
rf_has gitlab-self "[the guide](https://git.example.org/team/fixture/-/blob/$sha/$rel/docs/guide.md)"
rf_has gitlab-self "![diagram](https://git.example.org/team/fixture/-/raw/$sha/$rel/docs/diagram.png)"
rf_has gitlab-self "[Issues](https://git.example.org/team/fixture/-/issues)"
rf_warns gitlab-self MSKIT_PKG021
grep "warning MSKIT_PKG021" "$out/readme-gitlab-self.log" | grep -q "line 11" \
  && pass "readme gitlab-self: MSKIT_PKG021 names the README line" || bad "readme gitlab-self: MSKIT_PKG021 does not name line 11"
grep "warning MSKIT_PKG021" "$out/readme-gitlab-self.log" | grep -q "img.shields.io" \
  && bad "readme gitlab-self: an allowed image host was warned" || pass "readme gitlab-self: allowed image hosts are not warned"

# An unknown host: links stay relative, and the render checks on the generated file catch them.
rf_pack unknown Observer -p:RepositoryUrl=https://code.example.net/team/fixture -p:RepositoryCommit=$sha
rf_warns unknown MSKIT_PKG020
rf_warns unknown MSKIT_PKG017
rf_has unknown "[the guide](./docs/guide.md)"

# Overrides: provider, templates, an empty releases URL (link omitted), a custom issues URL.
rf_pack provider Observer -p:RepositoryUrl=https://code.example.net/team/fixture -p:RepositoryCommit=$sha -p:MSKit_RepoProvider=GitLab
rf_has provider "[the guide](https://code.example.net/team/fixture/-/blob/$sha/$rel/docs/guide.md)"
rf_quiet provider MSKIT_PKG020
rf_pack override Observer $gh \
  "-p:MSKit_RepoBlobUrlTemplate=https://src.example.net/{repoPath}/view/{commit}/{path}" \
  "-p:MSKit_RepoRawUrlTemplate=https://raw.githubusercontent.com/mirror/{repo}/{commit}/{path}" \
  "-p:MSKit_ReleasesUrl=" "-p:MSKit_IssuesUrl=https://tracker.example.net/fixture"
rf_has override "[the guide](https://src.example.net/DragoAnt/Fixture/view/$sha/$rel/docs/guide.md)"
rf_has override "![diagram](https://raw.githubusercontent.com/mirror/Fixture/$sha/$rel/docs/diagram.png)"
rf_hasnt override "[Release notes]"
rf_has override "[Issues](https://tracker.example.net/fixture)"

# A private repository: the links will not open for package readers.
rf_pack private Observer $gh -p:MSKit_RepositoryVisibility=private
rf_warns private MSKIT_PKG022

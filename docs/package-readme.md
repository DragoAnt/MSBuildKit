# Package readme from the repository README

Set one property and every package's readme is generated from the repository README when you run `dotnet pack`, so there is one file to keep current instead of a `package.readme.md` beside each project.

```xml
<!-- Directory.Build.props, below the kit import -->
<PropertyGroup>
  <MSKit_PackageReadmeFrom>README.md</MSKit_PackageReadmeFrom>
</PropertyGroup>
```

The path is relative to the git root (or absolute). It wins over a `package.readme.md` next to the csproj. The generated file is `obj/<Configuration>/package.readme.md`, packed as `readme.md`.

## What the generator does

1. **Relative links and images become absolute URLs pinned to the commit** (`RepositoryCommit`, which Source Link fills in for every pack; a release tag may not exist yet). A link goes to the file view, a link to a folder to the folder view, an image to the raw file. Anchors (`#install`), absolute URLs, and anything inside inline code or a fenced block are left alone. A root-relative path (`/docs/x.md`) is taken from the repository root, as GitHub does.
2. **`<!-- nuget:skip -->` … `<!-- /nuget:skip -->`** blocks are cut: CI badges, contributing notes, build setup.
3. **`<!-- nuget:only <PackageId> -->` … `<!-- /nuget:only -->`** blocks stay only in the readme of the packages they name (several ids: separate with spaces or commas). Unmarked content goes to every package, so a multi-package repository keeps one README.
4. **The title is the package id.** The first level-1 heading (`# …`, or a `===`-underlined one) becomes `# <PackageId>`, so each package of a multi-package repository is named on its own page; a README with no level-1 heading gets the title as its first line. Only the content this package keeps counts: a heading inside a `nuget:skip` block, another package's `nuget:only` block or a code fence is never the one replaced. Set `MSKit_PackageReadmeTitle` to another title, or empty to keep the README's own heading.
5. **Release notes and Issues links** are added to the overview when it does not already link those pages: the `## Overview` section when there is one, else the text above the first `##` heading.
6. The `MSKIT_PKG` checks then run on the generated file, so a link the generator could not rewrite is still caught by `MSKIT_PKG017` / `MSKIT_PKG009`.

The markers are matched on lines of their own, outside code fences. A README that documents the markers in a fenced block is safe.

## Repository hosts

The host is detected from `RepositoryUrl` (Source Link reads it from the git remote):

| Provider | Detected from | File link | Image | Releases | Issues |
| --- | --- | --- | --- | --- | --- |
| `GitHub` | `github.com`, `SourceLinkGitHubHost` items | `{repoUrl}/blob/{commit}/{path}` | `https://raw.githubusercontent.com/{repoPath}/{commit}/{path}` (Enterprise: `{repoUrl}/raw/…`) | `{repoUrl}/releases` | `{repoUrl}/issues` |
| `GitLab` | `gitlab.com`, `SourceLinkGitLabHost` items (self-hosted) | `{repoUrl}/-/blob/{commit}/{path}` | `{repoUrl}/-/raw/{commit}/{path}` | `{repoUrl}/-/releases` | `{repoUrl}/-/issues` |
| `AzureDevOps` | `dev.azure.com`, `*.visualstudio.com`, `SourceLinkAzureReposHost` | `{repoUrl}?path=/{path}&version=GC{commit}` | same | none | none |
| `Bitbucket` | `bitbucket.org`, `SourceLinkBitbucketGitHost` | `{repoUrl}/src/{commit}/{path}` | `{repoUrl}/raw/{commit}/{path}` | none | `{repoUrl}/issues` |
| `Gitea` | `codeberg.org`, `gitea.com`, `SourceLinkGiteaHost` | `{repoUrl}/src/commit/{commit}/{path}` | `{repoUrl}/raw/commit/{commit}/{path}` | `{repoUrl}/releases` | `{repoUrl}/issues` |

GitHub and GitLab are covered by the kit's self-test. Azure DevOps, Bitbucket and Gitea are first drafts: check their output once, and override the templates if a link is wrong. A folder link uses `/tree/` where the file link uses `/blob/`.

A self-hosted GitLab is recognised through the same item Source Link uses:

```xml
<ItemGroup>
  <SourceLinkGitLabHost Include="git.example.org" />
</ItemGroup>
```

## Properties

| Property | Default | Meaning |
| --- | --- | --- |
| `MSKit_PackageReadmeFrom` | empty (off) | The README to generate from, relative to the git root |
| `MSKit_RepoProvider` | detected | `GitHub`, `GitLab`, `AzureDevOps`, `Bitbucket` or `Gitea` |
| `MSKit_RepoBlobUrlTemplate` | the provider's | File links; a `/blob/` in it becomes `/tree/` for folders |
| `MSKit_RepoRawUrlTemplate` | the provider's | Images |
| `MSKit_ReleasesUrl` | `auto` | The release-notes page, also the default `PackageReleaseNotes` off GitHub; empty leaves the link out |
| `MSKit_IssuesUrl` | `auto` | The issues page; empty leaves the link out |
| `MSKit_PackageReadmeTitle` | `auto` (the `PackageId`) | The text of the first level-1 heading; empty keeps the README's own heading |
| `MSKit_RepositoryVisibility` | `$(CI_PROJECT_VISIBILITY)` | `private` or `internal` raises `MSKIT_PKG022` |
| `MSKit_GeneratedPackageReadmePath` | `obj/<Configuration>/package.readme.md` | Where the generated file goes |
| `MSKit_PackageReadmeAllowedImageHosts` | the kit's list | `;`-separated hosts that replace the list below |

Templates take `{repoUrl}`, `{host}`, `{repoPath}` (`owner/repo`, nested groups included), `{owner}`, `{repo}`, `{commit}` and `{path}`. To leave a link out, or keep the README's heading, set the property empty in the csproj, below the kit import, or with `-p:MSKit_IssuesUrl=`: an empty value in `Directory.Build.props` above the kit import is replaced by `auto`.

GitHub Actions does not expose the repository's visibility as a variable; pass it if you want the private-repository warning there:

```yaml
run: dotnet pack -c Release -p:MSKit_RepositoryVisibility=${{ github.event.repository.visibility }}
```

## Warnings

These stay warnings on CI; skip one with `MSKit_SkipPackageChecks` or `NoWarn` like the other checks.

| Code | Fires when |
| --- | --- |
| [`MSKIT_PKG020`](./reference/codes.md#mskitpkg020) | the README is missing, a marker is unbalanced, a path leaves the repository, or links cannot be rewritten (no repository URL, an unknown host, no commit) |
| [`MSKIT_PKG021`](./reference/codes.md#mskitpkg021) | an image is served from a host nuget.org does not render images from; the warning names the image and its README line |
| [`MSKIT_PKG022`](./reference/codes.md#mskitpkg022) | the repository is private or internal, so the links will not open for package readers |

## Allowed image hosts

nuget.org shows readme images only from [a fixed list of hosts](https://learn.microsoft.com/nuget/nuget-org/package-readme-on-nuget-org#allowed-domains-for-images-and-badges). The kit ships that list as `.toolkit/msbuild/DragoAnt.MSBuildKit.Packaging/nuget.allowed-image-hosts.txt` (copied from the page on 2026-10-05) and refreshes it with kit releases; nothing is downloaded during a build. `raw.githubusercontent.com` and `gitlab.com` are on it, so images from a GitHub or gitlab.com repository render; a self-hosted GitLab is not, and its images raise `MSKIT_PKG021`.

## Build cost

The generator runs on `dotnet pack` only, once per project (before `GenerateNuspec`), never on `dotnet build`, a design-time build or a per-framework inner build. It is incremental: the README, the kit's host list and a stamp of the settings above are its inputs, so a second pack with nothing changed skips it. One in-process pass, no network, no process started. The generator and the `MSKIT_PKG` checks are one inline task, so a pack compiles it once whichever of the two runs.

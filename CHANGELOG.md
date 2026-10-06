# Changelog

All notable changes to this project are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [SemVer](https://semver.org/).

## [Unreleased]

### Added

- `manager/`: the first build of `mskit-manager`, the `DragoAnt.MSBuildKit.Manager` .NET tool (`net8.0`, `net10.0`, `RollForward=Major`) that will install, update and migrate the kit. This build has one command, `status [--json]`, which prints the tool version; the logo goes to stderr, only on a terminal and never with `--no-logo`, so `--json` output always parses. Each run writes a log under `<system temp>/mskit-manager/logs/`, named after the command, newest 20 kept. Not published yet.

### Changed

- The documentation moved from the README into [docs/](./docs/README.md), one page per topic in reading order, with a [property reference](./docs/reference/properties.md) and a [code reference](./docs/reference/codes.md) that cover everything the kit sets, reads and reports. Corrected along the way: most packaging defaults apply to every project, not only packable ones; a Roslyn project imports its role's props itself; an update rewrites more than `.toolkit/msbuild/`; any tag build is a release build.

## [0.2.1] - 2026-10-05

### Added

- `MSKit_PackageReadmeTitle`: the readme generated from `MSKit_PackageReadmeFrom` replaces the README's first level-1 heading with `# <PackageId>`, so each package of a multi-package repository is titled on its own page; a README without one gets the title as its first line. Set another title, or empty to keep the README's heading. See [docs/package-readme.md](./docs/package-readme.md) ([#8](https://github.com/DragoAnt/MSBuildKit/pull/8)).

### Fixed

- `update.sh` no longer stops halfway (`unexpected EOF`, `kit.json` left at the old version) when the update replaces it with a copy of another length, as a CRLF checkout does: the script is parsed in full before it runs, and it copies the new `update.sh` / `update.ps1` as its last step. The fix applies to updates started from this version on. An update from 0.2.0 or earlier still runs the old script: it installs the files, then stops with a `syntax error` before writing `kit.json`; run the same command once more ([#8](https://github.com/DragoAnt/MSBuildKit/pull/8)).

## [0.2.0] - 2026-10-05

### Added

- `MSKit_PackageReadmeFrom=README.md` generates each package's readme from the repository README on `dotnet pack`: relative links and images become absolute URLs pinned to the commit (GitHub, GitLab including self-hosted hosts named by `SourceLinkGitLabHost`; first drafts for Azure DevOps, Bitbucket and Gitea), `<!-- nuget:skip -->` and `<!-- nuget:only <PackageId> -->` blocks pick each package's content, and release-notes and issues links are added to the overview. Overrides: `MSKit_RepoProvider`, `MSKit_RepoBlobUrlTemplate`, `MSKit_RepoRawUrlTemplate`, `MSKit_ReleasesUrl`, `MSKit_IssuesUrl` (empty leaves the link out). See [docs/package-readme.md](./docs/package-readme.md) ([#5](https://github.com/DragoAnt/MSBuildKit/pull/5)).
- Warnings `MSKIT_PKG020` (the readme cannot be generated as asked), `MSKIT_PKG021` (an image host nuget.org does not render, with its README line) and `MSKIT_PKG022` (a private or internal repository, from `MSKit_RepositoryVisibility` or GitLab's `CI_PROJECT_VISIBILITY`).

### Changed

- nuget.org's allowed image hosts moved from a property default to `nuget.allowed-image-hosts.txt` in the Packaging part, read only on pack; `MSKit_PackageReadmeAllowedImageHosts` still replaces it.

### Fixed

- A test project with a single `<TargetFramework>` (net8.0, net9.0, net10.0) no longer fails with a false `MSKIT_TEST005`, and on net8.0/net9.0 gets `TestingPlatformDotnetTestSupport`: the TfmConstants part now evaluates `IsNETxx` again in the targets phase, after the csproj body has set the framework. The props-phase values stay for multi-targeted inner builds ([#6](https://github.com/DragoAnt/MSBuildKit/pull/6)).
- `MSKIT_PKG016` no longer fires on GitLab and the other hosts the generated readme knows: with `MSKit_PackageReadmeFrom` set, an empty `PackageReleaseNotes` defaults to the releases page the readme links (`MSKit_ReleasesUrl`). GitHub keeps its tag release page; `MSKit_DefaultReleaseNotes=False` still turns the default off ([#6](https://github.com/DragoAnt/MSBuildKit/pull/6)).

## [0.1.1] - 2026-10-04

### Fixed

- Packages ship their XML documentation file again: the `GenerateDocumentationFile` default moved to the props phase, where the SDK still honours it, so a `CS1591` gate in a consuming repository fires too.

## [0.1.0] - 2026-10-03

### Added

- Kit parts: Core, Trunk (version engine, product defaults, reference audits), Vcs.GitHub, TfmConstants, Packaging, Testing and Testing.XUnit.v3, Locals (Secrets, DirectorySecrets, Compile), PrivateAssets, and the optional PackageAsProj, Project.RoslynComponent/CodeAnalyzer/CodeFixer/SourceGenerator, ProjMetadata and EF parts.
- `ReleaseTag` version strategy: release tags become the package version (a leading `v` is removed), branches `{prefix}-ci.{run}`, pull requests `{prefix}-pr.{n}.{run}`; an invalid tag fails with `MSKIT_VER006`.
- nuget.org packaging defaults and nineteen `MSKIT_PKG` checks, warnings locally and errors on CI.
- Microsoft.Testing.Platform v2 test projects with xUnit v3, Cobertura coverage, TRX and JUnit reports.
- `update.sh` and `update.ps1`: install or update `.toolkit/` from a SHA-256 checked release zip, with optional parts and a dry run.
- `samples/MinimalLibrary`, the `tests/run.sh` self-test, and the CI and release workflows, with every action pinned to a full commit SHA.

# DragoAnt.MSBuildKit

Shared MSBuild settings for .NET repositories that publish NuGet packages: nuget.org-ready package metadata with build-time checks, versions from release tags, and Microsoft.Testing.Platform tests with coverage. Installed as plain files you can read and review, updated by one script.

[![CI](https://img.shields.io/github/actions/workflow/status/DragoAnt/MSBuildKit/ci.yml?branch=main)](https://github.com/DragoAnt/MSBuildKit/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/DragoAnt/MSBuildKit)](https://github.com/DragoAnt/MSBuildKit/releases)
[![License](https://img.shields.io/github/license/DragoAnt/MSBuildKit)](./LICENSE)

## Features

- **Packages that pass nuget.org's rules by default.** Licence, icon, README, Source Link, symbols (`.snupkg`), repository and release-notes links, package validation and NuGet audit are set for every packable project. Nineteen checks (`MSKIT_PKG001`-`019`) run on `dotnet pack`: warnings on your machine, errors on CI.
- **One README for the repository and its packages.** `MSKit_PackageReadmeFrom=README.md` generates each package's readme on `dotnet pack`: relative links pinned to the commit on GitHub, GitLab and other hosts, per-package sections, release and issue links. See [docs/package-readme.md](./docs/package-readme.md).
- **Versions from release tags.** Publish a GitHub release `v1.4.0` and the packages are `1.4.0`. Branch builds are `1.4.0-ci.<run>`, pull requests `1.4.0-pr.<n>.<run>`, local builds `9999.0.0`. A tag that is not SemVer stops the build with `MSKIT_VER006`.
- **Tests on Microsoft.Testing.Platform v2.** Projects named `*.Tests` become xUnit v3 test projects with code coverage (Cobertura), TRX and JUnit reports, assertions and NSubstitute wired in, and `InternalsVisibleTo` from the code they test.
- **Plain files, one update script.** The kit lives in your repository's `.toolkit/` folder, so every change shows up in a pull request. `update.ps1` / `update.sh` installs a release after checking its SHA-256.
- Not a NuGet package or an MSBuild SDK: nothing is restored at build time.

## Install

From the repository root, with PowerShell 7 or a POSIX shell:

```sh
curl -fsSLO https://github.com/DragoAnt/MSBuildKit/releases/latest/download/update.sh
sh update.sh && rm update.sh
```

```powershell
Invoke-WebRequest https://github.com/DragoAnt/MSBuildKit/releases/latest/download/update.ps1 -OutFile update.ps1
pwsh ./update.ps1; Remove-Item update.ps1
```

The script writes `.toolkit/` and, when they are missing, a `Directory.Build.props` and `Directory.Build.targets` that import it. If you already have them, it prints the one import line each needs:

```xml
<!-- Directory.Build.props -->
<Import Project="$(MSBuildThisFileDirectory).toolkit/msbuild/init.props" />
<!-- Directory.Build.targets -->
<Import Project="$(MSBuildThisFileDirectory).toolkit/msbuild/init.targets" />
```

Then declare the next version in `Directory.Version.props` next to them, and commit `.toolkit/` with the rest:

```xml
<Project>
  <PropertyGroup>
    <VersionPrefix>1.4.0</VersionPrefix>
  </PropertyGroup>
</Project>
```

`samples/MinimalLibrary` is a complete example: one library, one test project, every check passing.

## Update

```sh
sh .toolkit/update.sh                    # the version pinned in .toolkit/kit.json, or the latest release
sh .toolkit/update.sh --version 0.2.0    # move to another version
sh .toolkit/update.sh --add EF --dry-run # preview adding an optional part
```

`pwsh .toolkit/update.ps1` takes the same options as `-Version`, `-Add`, `-Remove`, `-DryRun`, `-Source`, `-Sha256`, `-Repo`, `-Root`. The script downloads `msbuildkit-<version>.zip` from the release, compares its SHA-256 with the published `.sha256` (and with `kit.json` when the version did not change), and rewrites `.toolkit/msbuild/` only. `.toolkit/.local/` and your own files are left alone. `--source <folder or zip>` installs a local build of the kit.

## Parts

Default parts are always installed; add optional ones with `--add`.

| Part | Default | What it does |
| --- | --- | --- |
| `Core` | yes | Developer-vs-CI switch, solution and git roots, branch, `TargetFramework(s)` switching, Roslyn project-type detection |
| `Trunk` (`DragoAnt.MSBuildKit`) | yes | Language defaults, product and copyright, the version engine, global usings, reference audits |
| `Vcs.GitHub` | yes | Maps `GITHUB_*` variables: CI detection, run number, release tag, pull-request number, repository URL |
| `TfmConstants` | yes | `IsNET8` … `IsNET14`, `IsNET8_OR_GREATER` …, `IsNETSTANDARD` for conditions; final in item and target conditions and `Directory.Build.targets`, in the props phase only once the framework is known (an inner build of a multi-targeted project) |
| `Packaging` | yes | nuget.org metadata defaults and the `MSKIT_PKG` checks |
| `Testing`, `Testing.XUnit.v3` | yes | Test-project detection, Microsoft.Testing.Platform, coverage, TRX, xUnit v3 |
| `Locals.Secrets`, `Locals.DirectorySecrets`, `Locals.Compile` | yes | Local-only secrets and source files kept outside the repository |
| `PrivateAssets` | yes | `MSKit_ProjectReferenceAsPrivateAssets` / `MSKit_PackageReferenceAsPrivateAssets` |
| `PackageAsProj` | `--add` | Swap a `PackageReference` for a `ProjectReference` to debug a dependency from source |
| `Project.RoslynComponent`, `.CodeAnalyzer`, `.CodeFixer`, `.SourceGenerator` | `--add` | Packaging for analyzers, code fixes and source generators (`*.Analyzers`, `*.CodeFixes`, `*.SourceGenerator`) |
| `ProjMetadata` | `--add` | Writes each project's packages and assemblies to YAML (`-p:ProjMetadataOutDir=<dir>`) |
| `EF` | `--add` | Entity Framework migration scripts (`add-migration.ps1`, `apply-migrations.ps1`, …) |

## Versions

The default strategy is `ReleaseTag`. `VersionPrefix` is the next version the repository will release.

| Build | Version | Template property |
| --- | --- | --- |
| Local (no `GITHUB_RUN_ID`) | `9999.0.0` | always |
| Release tag `v2.0.0`, `2.0.0`, `v2.1.0-beta.1` | `2.0.0`, `2.0.0`, `2.1.0-beta.1` | `MSKit_ReleaseVersionTemplate` = `{releaseTag}` |
| Pull request 15, run 7 | `1.4.0-pr.15.7` | `MSKit_PullRequestVersionTemplate` = `{prefix}-pr.{prNumber}.{buildNumber}` |
| Any branch, run 7 | `1.4.0-ci.7` | `MSKit_VersionTemplate` = `{prefix}-ci.{buildNumber}` |

A `Version` passed by the caller (`-p:Version=2.0.0`, or set in `Directory.Build.props` above the import) always wins. Other strategies: `SemVer`, `SemVer4`, `DateBased`, `VersionTag`, `Manual` (`MSKit_VersionStrategy`). Placeholders: `{prefix}`, `{buildNumber}`, `{pipelineId}`, `{releaseTag}`, `{prNumber}`, `{branchSlug}`, `{branchTicket}`, `{branchAspectSuffix}`, `{buildDateUtcDash}`, `{buildDateUtcDot}`, `{versionTag}`, `{commitShaShort}`.

## Packaging rules

Defaults apply to projects with `IsPackable=True` and yield to any value you set.

| Property | Default | Why |
| --- | --- | --- |
| `PackageLicenseExpression` | `MIT` (owner layer) | [licensing](https://learn.microsoft.com/nuget/create-packages/package-authoring-best-practices#licensing) |
| `Authors`, `Copyright` | owner name; `Copyright (c) <year> <owner>` | [copyright](https://learn.microsoft.com/nuget/create-packages/package-authoring-best-practices#copyright) |
| `PackageIcon` | `.toolkit/res/package.icon.png` (128×128), packed as `icon.png` | [icon](https://learn.microsoft.com/nuget/create-packages/package-authoring-best-practices#icon) |
| `PackageReadmeFile` | generated from `MSKit_PackageReadmeFrom` ([package readme](./docs/package-readme.md)), else `package.readme.md` (else `README.md`) next to the csproj, packed as `readme.md` | [README](https://learn.microsoft.com/nuget/reference/msbuild-targets#packagereadmefile) |
| `RepositoryUrl`, `PackageProjectUrl` | from `GITHUB_REPOSITORY`, else the git remote via Source Link | [repository](https://learn.microsoft.com/nuget/create-packages/package-authoring-best-practices#repository-type-and-url) |
| `PackageReleaseNotes` | the GitHub release page of the tag, else the releases page; on other hosts, the releases page the generated readme links (`MSKit_PackageReadmeFrom`) | [release notes](https://learn.microsoft.com/nuget/create-packages/package-authoring-best-practices#release-notes) |
| `PublishRepositoryUrl`, `EmbedUntrackedSources`, `Deterministic`, `ContinuousIntegrationBuild` (CI) | `true` | [Source Link](https://learn.microsoft.com/dotnet/standard/library-guidance/sourcelink) |
| `IncludeSymbols`, `SymbolPackageFormat` | `true`, `snupkg` | [symbols](https://learn.microsoft.com/nuget/create-packages/symbol-packages-snupkg) |
| `EnablePackageValidation` | `true`; baseline from `MSKit_PackageValidationBaselineVersion` | [package validation](https://learn.microsoft.com/dotnet/fundamentals/apicompat/package-validation/overview) |
| `NuGetAudit`, `NuGetAuditMode` | `true`, `all` | [auditing](https://learn.microsoft.com/nuget/concepts/auditing-packages) |
| `GenerateDocumentationFile` | `True` | XML docs ship with the package |

### Checks

`dotnet pack` reports these as warnings locally and as errors on CI (`MSKit_PackageChecksAsErrors`). Skip one with `MSKit_SkipPackageChecks=MSKIT_PKG004` (several: separate with `;`, all: `All`) or by adding the code to `NoWarn`.

| Code | Fires when | Source |
| --- | --- | --- |
| `MSKIT_PKG001` | `Description` is missing, the SDK default or the package id | [description](https://learn.microsoft.com/nuget/create-packages/package-authoring-best-practices#description) |
| `MSKIT_PKG002` | `Description` is shorter than `MSKit_PackageDescriptionMinLength` (30) | [description](https://learn.microsoft.com/nuget/create-packages/package-authoring-best-practices#description) |
| `MSKIT_PKG003` | no README is packed | [README](https://learn.microsoft.com/nuget/create-packages/package-authoring-best-practices#readme) |
| `MSKIT_PKG004` | no `PackageTags` | [tags](https://learn.microsoft.com/nuget/create-packages/package-authoring-best-practices#tags) |
| `MSKIT_PKG005` | no icon | [icon](https://learn.microsoft.com/nuget/create-packages/package-authoring-best-practices#icon) |
| `MSKIT_PKG006` | no licence expression or file | [licensing](https://learn.microsoft.com/nuget/create-packages/package-authoring-best-practices#licensing) |
| `MSKIT_PKG007` | deprecated `PackageLicenseUrl` is set | [licensing](https://learn.microsoft.com/nuget/create-packages/package-authoring-best-practices#licensing) |
| `MSKIT_PKG008` | deprecated `PackageIconUrl` is set | [icon](https://learn.microsoft.com/nuget/create-packages/package-authoring-best-practices#icon) |
| `MSKIT_PKG009` | the package README has relative images | [allowed images](https://learn.microsoft.com/nuget/nuget-org/package-readme-on-nuget-org#allowed-domains-for-images-and-badges) |
| `MSKIT_PKG010` | the package README contains HTML | [supported Markdown](https://learn.microsoft.com/nuget/nuget-org/package-readme-on-nuget-org#supported-markdown-features) |
| `MSKIT_PKG011` | the package README uses GitHub alerts (`> [!NOTE]`) | [supported Markdown](https://learn.microsoft.com/nuget/nuget-org/package-readme-on-nuget-org#supported-markdown-features) |
| `MSKIT_PKG012` | the package README loads images from hosts nuget.org blocks | [allowed images](https://learn.microsoft.com/nuget/nuget-org/package-readme-on-nuget-org#allowed-domains-for-images-and-badges) |
| `MSKIT_PKG013` | the package version is not SemVer 2.0 | [package version](https://learn.microsoft.com/nuget/create-packages/package-authoring-best-practices#package-version) |
| `MSKIT_PKG014` | no repository or project URL | [repository](https://learn.microsoft.com/nuget/create-packages/package-authoring-best-practices#repository-type-and-url) |
| `MSKIT_PKG015` | the icon is not a 128×128 PNG (`MSKit_PackageIconSize`) | [icon](https://learn.microsoft.com/nuget/create-packages/package-authoring-best-practices#icon) |
| `MSKIT_PKG016` | no `PackageReleaseNotes` | [release notes](https://learn.microsoft.com/nuget/create-packages/package-authoring-best-practices#release-notes) |
| `MSKIT_PKG017` | the package README has relative links | [package README](https://learn.microsoft.com/nuget/nuget-org/package-readme-on-nuget-org) |
| `MSKIT_PKG018` | an open-source licence with an "All rights reserved" copyright | [copyright](https://learn.microsoft.com/nuget/create-packages/package-authoring-best-practices#copyright) |
| `MSKIT_PKG019` | the package README contains a Mermaid diagram | [supported Markdown](https://learn.microsoft.com/nuget/nuget-org/package-readme-on-nuget-org#supported-markdown-features) |

With `MSKit_PackageReadmeFrom` the checks read the generated readme, and three more warnings come from the generator; they stay warnings on CI ([package readme](./docs/package-readme.md#warnings)):

| Code | Fires when | Source |
| --- | --- | --- |
| `MSKIT_PKG020` | the README is missing, a `nuget:` marker is unbalanced, or links cannot be rewritten (no repository URL, unknown host, no commit) | [package readme](./docs/package-readme.md) |
| `MSKIT_PKG021` | an image comes from a host nuget.org does not render images from; names the image and its README line | [allowed images](https://learn.microsoft.com/nuget/nuget-org/package-readme-on-nuget-org#allowed-domains-for-images-and-badges) |
| `MSKIT_PKG022` | the repository is private or internal (`MSKit_RepositoryVisibility`), so the readme links will not open | [package readme](./docs/package-readme.md) |

## Tests and coverage

Projects whose name matches `MSKit_TestsProjectNameRegex` (default: ending in `.Tests`, `.UnitTests`, `.IntegrationTests`) are test projects; `*.TestsSuite`, `*.TestsFixtures` and `*.Fixtures` are test helper libraries (or set `IsTestsLibProject=True`). Add `"test": { "runner": "Microsoft.Testing.Platform" }` to `global.json`, then:

```sh
dotnet test --solution MyRepo.slnx -c Release --report-xunit-trx --report-xunit-junit --coverage --coverage-output-format cobertura --results-directory TestResults
```

| Property | Default | Meaning |
| --- | --- | --- |
| `MSKit_TestingFramework` | `xunit.v3` | Framework wiring |
| `MSKit_TestsAssertions` | `AwesomeAssertions` | `AwesomeAssertions`, `FluentAssertions` (`[7.2.2]`), `Shouldly` or `None` |
| `MSKit_TestsMocking` | `NSubstitute` | `NSubstitute` or `None` |
| `EnableMicrosoftTestingPlatform` | `True` | `False` falls back to VSTest |
| `InternalsVisibleToAllTestsProjects` | `True` | Code projects expose internals to the test projects under `MSKit_TestsDir` |
| `MSKit_PackageVersion_*` | see `.toolkit/msbuild/*/implicit.package.targets` | Central package versions the kit provides; `MSKit_ImplicitPackageVersions=False` turns them off |

## Other properties

| Property | Default | Meaning |
| --- | --- | --- |
| `IsPackable` | `True` (owner layer) | Test projects are never packable |
| `TreatWarningsAsErrors` | `True` (owner layer) | NuGet vulnerability warnings `NU1901`-`NU1904` stay warnings |
| `MSKit_IsStableBranchRegex` | `^(main\|release/.+)$` | Branches that use `MSKit_StableVersionTemplate` |
| `MSKit_PrereleasePackagePrefix` | `DragoAnt.` | `MSKIT_PRE001` warns about prerelease versions of these ids on a stable branch |
| `MSKit_RestrictPackageReference` items | `Moq` (error) | Banned or discouraged packages (`MSKIT_RES001`/`002`) |
| `MSKit_BeforeInitProps`, `MSKit_AfterInitProps`, `MSKit_BeforeInitTargets`, `MSKit_AfterInitTargets` | empty | Your own files imported around the kit |

To use the kit for another owner, fork it and edit `kit/.toolkit/msbuild/init.company.props` and `kit/.toolkit/res/package.icon.png`; nothing else names an owner.

## Migrating from MSBuild.Routine

1. Remove the submodule: `git rm .msbuild` and delete `.gitmodules` (and `submodules:` from your workflows).
2. Install the kit (`--add PackageAsProj` if you use `Directory.PackageAsProj.targets`) and replace the `.msbuild\shared\init.props` / `init.targets` imports with the `.toolkit/msbuild/` ones.
3. Drop what is now a default: `Copyright`, `PackageLicenseExpression`, `RepositoryUrl`, `PackageReleaseNotes`, `TargetFrameworkStrategy`, and the `.msbuild\tfm.constants.props` import.
4. Remove from `Directory.Packages.props` the versions the kit provides (`xunit.v3*`, `xunit.runner.visualstudio`, `Microsoft.NET.Test.Sdk`, `Microsoft.Testing.Extensions.CodeCoverage`, `NSubstitute*`, your assertion library, `coverlet.collector`), and the explicit `Microsoft.Testing.Extensions.CodeCoverage` references from test projects; `MSKIT_DUP001` lists any you missed. Keep FluentAssertions 7 with `MSKit_TestsAssertions=FluentAssertions`.
5. Add `Directory.Version.props` with the next `VersionPrefix`, and publish releases with tags such as `v2.0.1`.

| MSBuild.Routine | MSBuildKit |
| --- | --- |
| `IncrementVersionType` | `MSKit_VersionStrategy` |
| `IsDevEnv`, `Branch`, `BuildNumber`, `CommitSha` | `MSKit_IsDevEnv`, `MSKit_Branch`, `MSKit_BuildNumber`, `MSKit_CommitSha` |
| `SlnSecretsId`, `SecretsTemplatesDir` | `MSKit_SlnSecretsId`, `MSKit_Templates` |
| `TestsDir` | `MSKit_TestsDir` |
| `SkipCheck_*` | `MSKit_SkipAudit_*` |
| `IsCodeAnalizerLib` | the `Project.CodeAnalyzer` part (`*.Analyzers` projects) |

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md). Changes are listed in [CHANGELOG.md](./CHANGELOG.md).

## License

[MIT](./LICENSE)

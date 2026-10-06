# Packaging

The Packaging part sets what nuget.org expects from a package and checks it on `dotnet pack`. Every default yields to a value you set. The rules come from Microsoft's [package authoring best practices](https://learn.microsoft.com/nuget/create-packages/package-authoring-best-practices) and [package readme on nuget.org](https://learn.microsoft.com/nuget/nuget-org/package-readme-on-nuget-org).

## Build settings for every project

These apply to **all** projects, packable or not, so a library and the projects it references are built the same way:

| Property | Default | Why |
| --- | --- | --- |
| `PublishRepositoryUrl`, `EmbedUntrackedSources`, `Deterministic` | `true` | [Source Link](https://learn.microsoft.com/dotnet/standard/library-guidance/sourcelink) |
| `ContinuousIntegrationBuild` | `true` on CI only, so local PDBs keep real paths | [Source Link](https://learn.microsoft.com/dotnet/standard/library-guidance/sourcelink) |
| `GenerateDocumentationFile` | `True` | XML docs ship with the package |
| `NuGetAudit`, `NuGetAuditMode`, `NuGetAuditLevel` | `true`, `all`, `low` | [auditing packages](https://learn.microsoft.com/nuget/concepts/auditing-packages) |

## Package metadata

For projects with `IsPackable=True` (the owner layer makes that the default; test projects and code fixers are never packable):

| Property | Default | Rule |
| --- | --- | --- |
| `PackageId` | the project name | |
| `PackageLicenseExpression` | `MIT` (owner layer), unless `PackageLicenseFile` is set | [licensing](https://learn.microsoft.com/nuget/create-packages/package-authoring-best-practices#licensing) |
| `PackageRequireLicenseAcceptance` | `false` | |
| `Authors`, `Copyright` | the owner; `Copyright (c) <year> <owner>` ([Build](./build.md#language-and-product-defaults)) | [copyright](https://learn.microsoft.com/nuget/create-packages/package-authoring-best-practices#copyright) |
| `PackageIcon` | `PackageIconPath` (owner layer: `.toolkit/res/package.icon.png`, 128×128; PNG or JPEG) packed as `icon<extension, lowercased>` (`icon.png`, `icon.jpg`); a `PackageIcon` the project sets is kept | [icon](https://learn.microsoft.com/nuget/create-packages/package-authoring-best-practices#icon) |
| `PackageReadmeFile` | generated from `MSKit_PackageReadmeFrom` ([Package readme](./package-readme.md)), else `package.readme.md` next to the csproj, else `README.md` next to it; packed as `readme.md`. `MSKit_PackageReadmeSourcePath` names another file | [README](https://learn.microsoft.com/nuget/create-packages/package-authoring-best-practices#readme) |
| `RepositoryType`, `RepositoryUrl`, `PackageProjectUrl` | `git`; `GITHUB_SERVER_URL/GITHUB_REPOSITORY` on GitHub Actions, else the git remote [Source Link](https://learn.microsoft.com/dotnet/standard/library-guidance/sourcelink) reads, without `.git` | [repository](https://learn.microsoft.com/nuget/create-packages/package-authoring-best-practices#repository-type-and-url) |
| `PackageReleaseNotes` | on a `https://github.com/` repository the tag's release page on a tag build, else its releases page; on other hosts the releases page the generated readme links (needs `MSKit_PackageReadmeFrom`). `MSKit_DefaultReleaseNotes=False` turns the default off | [release notes](https://learn.microsoft.com/nuget/create-packages/package-authoring-best-practices#release-notes) |
| `IncludeSymbols`, `SymbolPackageFormat` | `true`, `snupkg` — `false` when `IncludeBuildOutput=false` or `DebugType` is `embedded` / `none`, since there is no PDB to ship | [symbol packages](https://learn.microsoft.com/nuget/create-packages/symbol-packages-snupkg) |
| `EnablePackageValidation` | `true`; `MSKit_PackageValidationBaselineVersion` (or `PackageValidationBaselineVersion`) also compares against that release | [package validation](https://learn.microsoft.com/dotnet/fundamentals/apicompat/package-validation/overview) |

Folders named `build/`, `buildMultiTargeting/` and `buildTransitive/` next to the csproj are packed under the same names, so a package can ship [MSBuild props and targets](https://learn.microsoft.com/nuget/concepts/msbuild-props-and-targets) by dropping them there.

Set `MSKit_PackageValidationBaselineVersion` to the last published version once there is one; package validation then reports API breaks against it.

## Checks

`dotnet pack` runs nineteen checks on each packable project. They are **warnings on a developer machine and errors on CI** (`MSKit_PackageChecksAsErrors`, default `True` when `MSKit_IsDevEnv` is not); every message names the rule and how to skip it.

| Code | Fires when |
| --- | --- |
| [`MSKIT_PKG001`](./reference/codes.md#mskitpkg001) | `Description` is missing, the SDK default, or the package id |
| [`MSKIT_PKG002`](./reference/codes.md#mskitpkg002) | `Description` is shorter than `MSKit_PackageDescriptionMinLength` (30) |
| [`MSKIT_PKG003`](./reference/codes.md#mskitpkg003) | no README is packed |
| [`MSKIT_PKG004`](./reference/codes.md#mskitpkg004) | no `PackageTags` |
| [`MSKIT_PKG005`](./reference/codes.md#mskitpkg005) | no icon |
| [`MSKIT_PKG006`](./reference/codes.md#mskitpkg006) | no licence expression or file |
| [`MSKIT_PKG007`](./reference/codes.md#mskitpkg007) | the deprecated `PackageLicenseUrl` is set |
| [`MSKIT_PKG008`](./reference/codes.md#mskitpkg008) | the deprecated `PackageIconUrl` is set |
| [`MSKIT_PKG009`](./reference/codes.md#mskitpkg009) | the README has relative images |
| [`MSKIT_PKG010`](./reference/codes.md#mskitpkg010) | the README contains HTML |
| [`MSKIT_PKG011`](./reference/codes.md#mskitpkg011) | the README uses GitHub alerts (`> [!NOTE]`) |
| [`MSKIT_PKG012`](./reference/codes.md#mskitpkg012) | the README loads images from a host nuget.org blocks |
| [`MSKIT_PKG013`](./reference/codes.md#mskitpkg013) | the version is not SemVer 2.0 (`MSKit_SemVerRegex`) |
| [`MSKIT_PKG014`](./reference/codes.md#mskitpkg014) | no repository or project URL |
| [`MSKIT_PKG015`](./reference/codes.md#mskitpkg015) | the icon is not a 128×128 PNG or JPEG (`MSKit_PackageIconSize`) |
| [`MSKIT_PKG016`](./reference/codes.md#mskitpkg016) | no `PackageReleaseNotes` |
| [`MSKIT_PKG017`](./reference/codes.md#mskitpkg017) | the README has relative links |
| [`MSKIT_PKG018`](./reference/codes.md#mskitpkg018) | an open-source licence with an "All rights reserved" copyright |
| [`MSKIT_PKG019`](./reference/codes.md#mskitpkg019) | the README contains a Mermaid diagram |

Images, links, HTML and alerts inside a fenced block or inline code are ignored; a GitHub Actions workflow badge from `github.com` counts as an allowed image. The readme generator adds three warnings of its own, `MSKIT_PKG020`-`022`, which stay warnings on CI ([Package readme](./package-readme.md#warnings)).

**Skipping a check:** list its code in `MSKit_SkipPackageChecks` (`MSKIT_PKG004;MSKIT_PKG016`) or in `NoWarn`; `MSKit_SkipPackageChecks=All` skips them all. Set it in a csproj to skip for one package.

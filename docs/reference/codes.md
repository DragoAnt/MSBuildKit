# Code reference

Every warning and error the kit reports, one section per code. The kit reports each code as `MSKIT_<FAMILY><nnn>` (for example `MSKIT_VER006`); the section anchors use the id without the underscore (`#mskitver006`). Severity is the default; the section says how to change or skip it.

| Family | Part | Codes |
| --- | --- | --- |
| [Packaging](#packaging) | Packaging | `PKG001`-`PKG022` |
| [Versioning](#versioning) | Trunk | `VER001`, `VER002`, `VER004`, `VER006`, `VER007` |
| [References](#references) | Trunk | `DUP001`, `PRE001`, `RES001`-`RES004` |
| [Shared properties](#shared-properties) | Trunk | `SHARED006`-`SHARED010`, `SHARED020` |
| [Project types](#project-types) | Core | `CORE001`, `ROSLYN001`-`ROSLYN003` |
| [Testing](#testing) | Testing, Testing.XUnit.v3 | `TEST005`, `TEST010`-`TEST014`, `TEST020`-`TEST022`, `TEST025`, `TEST026`, `TEST030`, `TEST031` |
| [PackageAsProj](#packageasproj) | PackageAsProj | `PAP001`, `PAP002` |

## Packaging

`PKG001`-`PKG019` run on `dotnet pack` for packable projects: **warnings on a developer machine, errors on CI** (`MSKit_PackageChecksAsErrors`). Skip one with `MSKit_SkipPackageChecks=<code>` (several separated by `;`, all with `All`) or by adding the code to `NoWarn`. `PKG020`-`PKG022` come from the readme generator and stay warnings. Background: [Packaging](../packaging.md), [Package readme](../package-readme.md).

### MSKITPKG001

`MSKIT_PKG001` — the package has no real `Description`: it is empty, the SDK's `Package Description`, the package id or the project name. Write one or two sentences on what the package does and what sets it apart; nuget.org search shows it first.

### MSKITPKG002

`MSKIT_PKG002` — `Description` is shorter than `MSKit_PackageDescriptionMinLength` (30 characters). Say what it does and for whom, or lower the bar.

### MSKITPKG003

`MSKIT_PKG003` — no README is packed. Add `package.readme.md` (or `README.md`) next to the csproj, or set `MSKit_PackageReadmeFrom`.

### MSKITPKG004

`MSKIT_PKG004` — no `PackageTags`. Add a few search terms that are not already in the package id.

### MSKITPKG005

`MSKIT_PKG005` — no icon. Set `PackageIconPath` to a 128×128 PNG; the owner layer sets one for every package.

### MSKITPKG006

`MSKIT_PKG006` — no licence. Set `PackageLicenseExpression` to an [SPDX id](https://spdx.org/licenses/) or `PackageLicenseFile`.

### MSKITPKG007

`MSKIT_PKG007` — the deprecated `PackageLicenseUrl` is set. Use `PackageLicenseExpression` or `PackageLicenseFile`.

### MSKITPKG008

`MSKIT_PKG008` — the deprecated `PackageIconUrl` is set. Pack the image and use `PackageIcon` or `PackageIconPath`.

### MSKITPKG009

`MSKIT_PKG009` — the package README has relative images, which nuget.org does not render. Use absolute `https` URLs from an [allowed host](https://learn.microsoft.com/nuget/nuget-org/package-readme-on-nuget-org#allowed-domains-for-images-and-badges), or generate the readme with `MSKit_PackageReadmeFrom`.

### MSKITPKG010

`MSKIT_PKG010` — the package README contains HTML, which nuget.org does not render. Use Markdown.

### MSKITPKG011

`MSKIT_PKG011` — the package README uses GitHub alerts (`> [!NOTE]`), which nuget.org shows as plain quotes. Use a bold lead-in such as `**Note:**`.

### MSKITPKG012

`MSKIT_PKG012` — the package README loads images from a host nuget.org blocks. Host them on an allowed domain (`img.shields.io`, `raw.githubusercontent.com`, …).

### MSKITPKG013

`MSKIT_PKG013` — the package version is not [SemVer 2.0](https://semver.org/) (`MSKit_SemVerRegex`).

### MSKITPKG014

`MSKIT_PKG014` — no repository or project URL. Set `RepositoryUrl`, or build from a git clone whose `origin` remote Source Link can read.

### MSKITPKG015

`MSKIT_PKG015` — the icon is not a PNG of `MSKit_PackageIconSize` × `MSKit_PackageIconSize` pixels (128).

### MSKITPKG016

`MSKIT_PKG016` — no `PackageReleaseNotes`. The kit fills them on `github.com`, and on any host the generated readme knows with `MSKit_PackageReadmeFrom`; elsewhere set them (a link to the changelog is enough).

### MSKITPKG017

`MSKIT_PKG017` — the package README has relative links, which break on nuget.org. Use absolute URLs, or generate the readme with `MSKit_PackageReadmeFrom`.

### MSKITPKG018

`MSKIT_PKG018` — the package has an open-source licence expression, but its `Copyright` says "all rights reserved". Use `Copyright (c) YEAR OWNER`.

### MSKITPKG019

`MSKIT_PKG019` — the package README contains a Mermaid diagram, which nuget.org shows as code. Link to the diagram on the repository host instead.

### MSKITPKG020

`MSKIT_PKG020` (warning) — the readme cannot be generated as asked: the `MSKit_PackageReadmeFrom` file is missing, a `nuget:skip` / `nuget:only` marker is unbalanced, a link leaves the repository, or links cannot be rewritten (no repository URL, an unknown host or provider, no commit). The message names the line.

### MSKITPKG021

`MSKIT_PKG021` (warning) — a generated readme loads an image from a host nuget.org does not render images from; the message names the image and its README line.

### MSKITPKG022

`MSKIT_PKG022` (warning) — the repository is private or internal (`MSKit_RepositoryVisibility`, else GitLab's `CI_PROJECT_VISIBILITY`), so the readme's links will not open for package readers.

## Versioning

Background: [Versioning](../versioning.md).

### MSKITVER001

`MSKIT_VER001` (error) — the csproj declares `<Version>` while a template strategy renders the version, so the value would be ignored. Remove it and declare `VersionPrefix` in `Directory.Version.props`, or set `MSKit_VersionStrategy=Manual`.

### MSKITVER002

`MSKIT_VER002` (error) — a version template uses an unknown placeholder. The message lists the valid ones ([placeholders](../versioning.md#placeholders)).

### MSKITVER004

`MSKIT_VER004` (error) — `MSKit_VersionStrategy=VersionTag` but `VersionTag` is empty. Pass `-p:VersionTag=1.2.3`, or use `ReleaseTag`.

### MSKITVER006

`MSKIT_VER006` (error, stops restore) — a tag build whose tag, after removing a leading `v`, is not [SemVer 2.0](https://semver.org/) (`MSKit_ReleaseTagRegex`). Delete the tag and its release and tag again (`v2.1.0`, `v2.1.0-beta.1`).

### MSKITVER007

`MSKIT_VER007` (warning) — the tag's `MAJOR.MINOR.PATCH` differs from the `VersionPrefix` the repository declares. Bump `VersionPrefix` after the release so branch builds sort above it; `MSKit_SkipAudit_ReleaseTagPrefix=True` silences it.

## References

Background: [reference checks](../build.md#reference-checks), [central package versions](../build.md#central-package-versions).

### MSKITDUP001

`MSKIT_DUP001` (error, stops restore) — `Directory.Packages.props` declares a `PackageVersion` the kit already provides. Delete the line; to pin another version set the kit's `MSKit_PackageVersion_*` property, or turn the kit's versions off with `MSKit_ImplicitPackageVersions=False`. `MSKit_SkipAudit_ImplicitPackageDuplicates=True` skips the check.

### MSKITPRE001

`MSKIT_PRE001` (warning) — a stable-branch build references a prerelease version of a package whose id starts with `MSKit_PrereleasePackagePrefix`. Use a stable version; `MSKit_PrereleasePackageCheckAsWarning=false` makes it an error.

### MSKITRES001

`MSKIT_RES001` (error) — a referenced package is banned by an `MSKit_RestrictPackageReference` item with `Type="Error"`. Remove it or use the suggested alternative; `SkipGlobalRestriction="True"` on the one `PackageReference` turns it into a warning.

### MSKITRES002

`MSKIT_RES002` (warning) — a referenced package is discouraged by an `MSKit_RestrictPackageReference` item with `Type="Warning"`. `SkipGlobalRestriction="True"` on the reference silences it.

### MSKITRES003

`MSKIT_RES003` (error) — with `MSKit_RestrictProjectReferences=True` (or `MSKit_RestrictReferences=True`), a `ProjectReference` lacks `Allowed="True"`.

### MSKITRES004

`MSKIT_RES004` (error) — with `MSKit_RestrictPackageReferences=True` (or `MSKit_RestrictReferences=True`), a `PackageReference` lacks `Allowed="True"`.

## Shared properties

Background: [target frameworks declared once](../build.md#target-frameworks-declared-once).

### MSKITSHARED006

`MSKIT_SHARED006` (error) — the csproj declares the same `TargetFramework` as `Directory.Build.props`. Delete it from the csproj.

### MSKITSHARED007

`MSKIT_SHARED007` (error) — the csproj declares the same `TargetFrameworks` as `Directory.Build.props`. Delete it from the csproj.

### MSKITSHARED008

`MSKIT_SHARED008` (warning) — the csproj overrides the shared `TargetFramework` with another value. Remove it, or accept it with `MSKit_SkipAudit_TargetFrameworkOverride=True` in the csproj.

### MSKITSHARED009

`MSKIT_SHARED009` (warning) — the csproj overrides the shared `TargetFrameworks` with another value. Remove it, or accept it with `MSKit_SkipAudit_TargetFrameworkOverride=True`.

### MSKITSHARED010

`MSKIT_SHARED010` (error) — the csproj declares both `TargetFramework` and `TargetFrameworks` (an empty `<TargetFramework></TargetFramework>` counts). Keep one.

### MSKITSHARED020

`MSKIT_SHARED020` (error, developer machines only) — the csproj's final `TreatWarningsAsErrors` differs from the shared value. Align it, or set `MSKit_SkipAudit_TreatWarningsAsErrors=True`.

## Project types

Background: [Roslyn components](../roslyn.md).

### MSKITCORE001

`MSKIT_CORE001` (error) — the project name matches more than one detection regex (analyzer, code fix, source generator). Rename the project, narrow a `MSKit_*ProjectNameRegex`, or set the matching `MSKit_Disable*AutoDetect=true` in `Directory.Build.props` above the kit import.

### MSKITROSLYN001

`MSKIT_ROSLYN001` (error) — the name matches the analyzer regex, but the `Project.CodeAnalyzer` part is not installed. `sh .toolkit/update.sh --add Project.CodeAnalyzer`, or rename the project, or set `MSKit_DisableCodeAnalyzerAutoDetect=true` in `Directory.Build.props` above the kit import.

### MSKITROSLYN002

`MSKIT_ROSLYN002` (error) — the name matches the code-fix regex, but `Project.CodeFixer` is not installed. Add the part, rename, or set `MSKit_DisableCodeFixerAutoDetect=true` in `Directory.Build.props` above the kit import.

### MSKITROSLYN003

`MSKIT_ROSLYN003` (error) — the name matches the source-generator regex, but `Project.SourceGenerator` is not installed. Add the part, rename, or set `MSKit_DisableSourceGeneratorAutoDetect=true` in `Directory.Build.props` above the kit import.

## Testing

Background: [Testing](../testing.md).

### MSKITTEST005

`MSKIT_TEST005` (error) — an xUnit v3 test project targets a framework older than net8.0.

### MSKITTEST010

`MSKIT_TEST010` (error) — `$(TestsProjectCommonPropsPath)` was imported before `MSKit_TestingFramework` was set. Put the `PropertyGroup` above the `Import`.

### MSKITTEST011

`MSKIT_TEST011` (error) — `MSKit_TestingFramework` changed after `$(TestsProjectCommonPropsPath)` was imported. Move the `PropertyGroup` above the `Import`.

### MSKITTEST012

`MSKIT_TEST012` (error) — no wiring exists for the `MSKit_TestingFramework` of an explicit test project. Use `xunit.v3`, or point `MSKit_TestingFramework_CommonPropsPath` at your own props file.

### MSKITTEST013

`MSKIT_TEST013` (error) — the csproj sets `IsTestsProject` directly, too late for the props-phase wiring. Rename the project to match `MSKit_TestsProjectNameRegex`, or use the explicit endpoint `$(TestsProjectCommonPropsPath)`.

### MSKITTEST014

`MSKIT_TEST014` (error) — the name matches the test-project regex, but the project is marked as a test helper library. Rename it (`Acme.TestUtils`), narrow the regex, or drop the helper-library flag.

### MSKITTEST020

`MSKIT_TEST020` (error) — `$(TestsLibProjectCommonPropsPath)` was imported before `MSKit_TestingFramework` was set.

### MSKITTEST021

`MSKIT_TEST021` (error) — `MSKit_TestingFramework` changed after `$(TestsLibProjectCommonPropsPath)` was imported.

### MSKITTEST022

`MSKIT_TEST022` (error) — no helper-library wiring exists for `MSKit_TestingFramework`. Use `xunit.v3`, or set `MSKit_TestingFramework_LibCommonPropsPath`.

### MSKITTEST025

`MSKIT_TEST025` (error) — a test project or helper library has no `MSKit_TestingFramework`. Set it in `Directory.Build.props` (the owner layer sets `xunit.v3`).

### MSKITTEST026

`MSKIT_TEST026` (error) — no installed part wires the `MSKit_TestingFramework` value. Use `xunit.v3` (part `Testing.XUnit.v3`), or set `MSKit_TestingFramework_CommonPropsPath`.

### MSKITTEST030

`MSKIT_TEST030` (warning) — `MSKit_TestsDir` is empty, so `InternalsVisibleTo` cannot be added. Set it, or turn `InternalsVisibleToAllTestsProjects` off.

### MSKITTEST031

`MSKIT_TEST031` (warning) — `MSKit_TestsDir` points at a folder that does not exist.

## PackageAsProj

Background: [PackageAsProj](../optional-parts.md#packageasproj).

### MSKITPAP001

`MSKIT_PAP001` (error) — a package switched to a `ProjectReference` is still resolved from the package. Run `dotnet restore --force`.

### MSKITPAP002

`MSKIT_PAP002` (error) — a package switched back from a project is not restored yet. Run `dotnet restore --force`, or set `PackageAsProj_SkipChecks=True`.

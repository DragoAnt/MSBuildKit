# Build defaults and checks

What the Core, Trunk, TfmConstants and PrivateAssets parts set for every project, and the checks that keep a repository consistent. Every default yields to a value you set ([load order](./parts.md#load-order)); every property is in the [property reference](./reference/properties.md).

## Language and product defaults

| Property | Default |
| --- | --- |
| [`Nullable`](https://learn.microsoft.com/dotnet/csharp/language-reference/compiler-options/language#nullable), [`ImplicitUsings`](https://learn.microsoft.com/dotnet/core/project-sdk/overview#implicit-using-directives) | `enable` |
| [`LangVersion`](https://learn.microsoft.com/dotnet/csharp/language-reference/configure-language-version) | `latest` |
| [`EnforceCodeStyleInBuild`](https://learn.microsoft.com/dotnet/fundamentals/code-analysis/overview#code-style-analysis) | `True` |
| `GeneratePackageOnBuild` | `False` |
| `AssemblyTitle` | the project name |
| `Authors`, `LegalTrademarks` | `$(ManufacturerName)` |
| `Company` | `$(FullManufacturerName)` |
| `Copyright` | `Copyright (c) <current UTC year> $(FullManufacturerName)` — no "All rights reserved", which contradicts an open-source licence |

The owner layer adds `IsPackable=True`, `TreatWarningsAsErrors=True`, `NoWarn` `CS1591;xUnit1051` and keeps NuGet vulnerability warnings `NU1901`-`NU1904` as warnings ([Customizing](./customizing.md#the-owner-layer)).

## Developer machine or CI

`MSKit_IsDevEnv` is `True` unless the Vcs.GitHub part sees `GITHUB_RUN_ID`, which GitHub Actions sets for every job. It decides:

| | Developer machine | CI |
| --- | --- | --- |
| Version | `9999.0.0` | from the tag, pull request or run ([Versioning](./versioning.md)) |
| `MSKIT_PKG` checks | warnings | errors ([Packaging](./packaging.md)) |
| [`ContinuousIntegrationBuild`](https://learn.microsoft.com/dotnet/core/project-sdk/msbuild-props#continuousintegrationbuild) | unset (PDBs keep real paths) | `true` |
| Local secrets | created from templates | deleted ([Local files](./local-files.md)) |
| `TreatWarningsAsErrors` drift check | on | off: CI passes its own `-p:TreatWarningsAsErrors` |

Set `MSKit_IsDevEnv` yourself to build "as CI" locally (`-p:MSKit_IsDevEnv=False`).

## Roots, branch and commit

| Property | Value |
| --- | --- |
| `MSKit_SlnFileDirectory` | the folder of the `.slnx` being built (`SlnxFilePath`), else the folder that holds `.toolkit/`; ends with `/` |
| `MSKit_SlnFileName` | the solution name without extension, when building a `.slnx` |
| `MSKit_GitRoot` | the nearest folder above the project with a `.git` (worktrees included) |
| `MSKit_ToolkitDir`, `MSKit_ToolkitMSBuildDir` | `.toolkit/` and `.toolkit/msbuild/`, absolute, ending with `/` |
| `MSKit_ProjectObjDir` | the project's `obj` folder, absolute |
| `MSKit_Branch` | on GitHub Actions `GITHUB_HEAD_REF` (pull requests) or `GITHUB_REF_NAME`; else read from `.git/HEAD`; else `unknown-branch` |
| `MSKit_IsStableBranch` | `true` when `MSKit_Branch` matches `MSKit_IsStableBranchRegex` (case-insensitive): the owner layer's `^(main\|release/.+)$`, the kit's own default `^(main\|master\|release/.+)$` |
| `MSKit_CommitSha` | `GITHUB_SHA` on CI, empty on a developer machine |

The kit imports these files from `MSKit_SlnFileDirectory` when they exist: `Directory.Version.props`, `Directory.GlobalUsings.props` / `.targets`, `Directory.Packages.Metadata.targets`, `Directory.PackageAsProj.targets` ([Customizing](./customizing.md#extension-files)).

## Target frameworks declared once

Declare `TargetFramework` or `TargetFrameworks` once, in `Directory.Build.props` above the kit import, and leave it out of the projects. A project that needs the other shape declares only that one; the kit clears the shared value of the shape the project does not use, so a library can multi-target while one tool project targets a single framework. The props phase reads the two files as text for this, because the SDK fixes cross-targeting before the targets phase.

| Code | When |
| --- | --- |
| [`MSKITSHARED006`](./reference/codes.md#mskitshared006), [`MSKITSHARED007`](./reference/codes.md#mskitshared007) | error: the csproj repeats the shared `TargetFramework` / `TargetFrameworks` value |
| [`MSKITSHARED008`](./reference/codes.md#mskitshared008), [`MSKITSHARED009`](./reference/codes.md#mskitshared009) | warning: the csproj sets a different value of the same shape; `MSKit_SkipAudit_TargetFrameworkOverride=True` accepts it |
| [`MSKITSHARED010`](./reference/codes.md#mskitshared010) | error: the csproj declares both shapes |

`MSKit_GuardXmlPeekRoutine=False` and `MSKit_GuardXmlPeekAudit=False` turn off a cheap text pre-check and always parse the csproj; leave them alone unless a declaration is missed.

## Target framework constants

The TfmConstants part sets these to `True` for conditions in items, targets and `Directory.Build.targets`:

| Property | `True` when `TargetFramework` is |
| --- | --- |
| `IsNET7` … `IsNET14` | `net7.0` … `net14.0` |
| `IsNET7_OR_GREATER` … `IsNET14_OR_GREATER` | that version or later, up to `net14.0` |
| `IsNETSTANDARD20`, `IsNETSTANDARD21`, `IsNETSTANDARD` | `netstandard2.0`, `netstandard2.1`, either |
| `IsNETFRAMEWORK` | `net48` (only that one) |
| `IsNETFRAMEWORK_OR_STANDARD` | `IsNETFRAMEWORK` or `IsNETSTANDARD` |

`TargetFrameworkVersionMajor` holds `7` … `14`. They are evaluated twice: in the props phase, where only a multi-targeted inner build knows its framework, and again in the targets phase, after the csproj body, where a single `TargetFramework` is known too. A `PropertyGroup` in the csproj itself runs between the two and cannot rely on them for a single-framework project.

```xml
<ItemGroup Condition="'$(IsNET8_OR_GREATER)'=='True'">
  <PackageReference Include="System.IO.Hashing" />
</ItemGroup>
```

## Global usings

Every project except analyzers and source generators gets `global using` for `System.Diagnostics.CodeAnalysis` and `System.Runtime.CompilerServices`, and `global using static` for `System.Runtime.CompilerServices.MethodImplOptions` and (not on `netstandard2.0`) `System.Diagnostics.CodeAnalysis.DynamicallyAccessedMemberTypes`. `MSKit_IncludeCodeAnalysisGlobalUsings=False` turns them off. Add your own in `Directory.GlobalUsings.props` / `.targets` next to the solution.

A project with `ExcludeFromCodeCoverage=true` gets the [`[ExcludeFromCodeCoverage]`](https://learn.microsoft.com/dotnet/api/system.diagnostics.codeanalysis.excludefromcodecoverageattribute) assembly attribute; test projects set it by default.

## Central package versions

The parts that add package references also provide their versions: as `PackageVersion` items with [central package management](https://learn.microsoft.com/nuget/consume-packages/central-package-management), else on the `PackageReference` itself when it has no version. Each version is a property you can override, `MSKit_PackageVersion_<Package>` (lists: [Testing](./testing.md#package-versions), [Roslyn](./roslyn.md#package-versions)); `MSKit_ImplicitPackageVersions=False` turns them all off. A `PackageVersion` of yours for the same id fails restore with [`MSKITDUP001`](./reference/codes.md#mskitdup001) (bypass: `MSKit_SkipAudit_ImplicitPackageDuplicates=True`).

`PrivateAssets=all` is set on references to `Fody`, `ConfigureAwait.Fody`, `IgnoresAccessChecksToGenerator`, `Grpc.Tools`, `Microsoft.EntityFrameworkCore.Design` and `Microsoft.EntityFrameworkCore.Tools`, so these build-time tools never become package dependencies. Add your own `Update` items in `Directory.Packages.Metadata.targets`.

## Reference checks

**Banned and discouraged packages.** Each `MSKit_RestrictPackageReference` item names a package:

```xml
<ItemGroup>
  <MSKit_RestrictPackageReference Include="Moq" Type="Error" Message="Use NSubstitute for test doubles." />
  <MSKit_RestrictPackageReference Include="Newtonsoft.Json" Type="Warning" Message="Prefer System.Text.Json." />
</ItemGroup>
```

A reference to a `Type="Error"` package fails with [`MSKITRES001`](./reference/codes.md#mskitres001), a `Type="Warning"` one warns with [`MSKITRES002`](./reference/codes.md#mskitres002). `SkipGlobalRestriction="True"` on one `PackageReference` allows it (an error becomes a warning). The owner layer bans `Moq`.

**Allow-list mode.** With `MSKit_RestrictProjectReferences=True` (or `MSKit_RestrictPackageReferences`, or `MSKit_RestrictReferences` for both) every reference must carry `Allowed="True"`, else [`MSKITRES003`](./reference/codes.md#mskitres003) / [`MSKITRES004`](./reference/codes.md#mskitres004). Off by default.

**Prerelease dependencies on a stable branch.** On a stable branch a reference to a prerelease version of a package whose id starts with `MSKit_PrereleasePackagePrefix` (owner layer: `DragoAnt.`) warns with [`MSKITPRE001`](./reference/codes.md#mskitpre001); `MSKit_PrereleasePackageCheckAsWarning=false` makes it an error.

**`TreatWarningsAsErrors` drift.** On a developer machine a csproj that changes the shared `TreatWarningsAsErrors` fails with [`MSKITSHARED020`](./reference/codes.md#mskitshared020); `MSKit_SkipAudit_TreatWarningsAsErrors=True` allows it.

## Private references

The PrivateAssets part sets `PrivateAssets="All"` on every `ProjectReference` of a project with `MSKit_ProjectReferenceAsPrivateAssets=True`, and on every `PackageReference` with `MSKit_PackageReferenceAsPrivateAssets=True`, so they do not flow to projects and packages that depend on it.

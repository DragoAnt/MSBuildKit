# Property reference

Every property and item the kit sets or reads, grouped by topic. **Set** = a value you may set (its default is shown); **out** = a value the kit computes for you to read; setting it yourself is not supported unless the row says so. Names without the `MSKit_` prefix are the kit's own too; standard SDK properties the kit only defaults (`Nullable`, `PackageId`, …) are on the topic pages.

## Hooks

| Name | Kind | Default | Meaning |
| --- | --- | --- | --- |
| `MSKit_BeforeInitProps`, `MSKit_AfterInitProps` | set | empty | A file imported before / after the kit's props ([Customizing](../customizing.md#hooks-around-the-kit)) |
| `MSKit_BeforeInitTargets`, `MSKit_AfterInitTargets` | set | empty | A file imported before / after the kit's targets |

## Machine, CI and paths

| Name | Kind | Default | Meaning |
| --- | --- | --- | --- |
| `MSKit_IsDevEnv` | set | `True`; `False` when `GITHUB_RUN_ID` is set | Developer machine or CI ([Build](../build.md#developer-machine-or-ci)) |
| `MSKit_IsGitHubCI` | out | | `True` on GitHub Actions |
| `MSKit_VcsProvider` | out | `GitHub` | The CI provider the Vcs part maps |
| `MSKit_CIPipelineId` | set | `GITHUB_RUN_ID`, else `0` | `{pipelineId}` |
| `MSKit_BuildNumber` | set | `GITHUB_RUN_NUMBER`, else `0` | `{buildNumber}` |
| `MSKit_CommitSha` | set | `GITHUB_SHA` on CI, else empty | `{commitShaShort}`, and the commit a generated readme pins links to when Source Link has none |
| `MSKit_Branch` | set | from GitHub Actions or `.git/HEAD`, else `unknown-branch` | [Roots, branch and commit](../build.md#roots-branch-and-commit) |
| `MSKit_IsStableBranchRegex` | set | owner layer `^(main\|release/.+)$`; kit `^(main\|master\|release/.+)$` | Branches that use `MSKit_StableVersionTemplate` and the prerelease check |
| `MSKit_IsStableBranch` | out | | `true` when `MSKit_Branch` matches |
| `MSKit_GitRoot` | set | the nearest folder with `.git` | |
| `MSKit_SlnFileDirectory` | set | the `.slnx` folder, else the folder holding `.toolkit/` | Where the extension files are looked up |
| `MSKit_SlnFileName` | set | the `.slnx` name | |
| `MSKit_ToolkitDir`, `MSKit_ToolkitMSBuildDir` | out | | `.toolkit/` and `.toolkit/msbuild/`, absolute |
| `MSKit_ProjectObjDir` | out | | The project's `obj` folder, absolute |
| `MSKit_Templates` | set | `.toolkit/.local/` | Templates for local files ([Local files](../local-files.md)) |
| `MSKit_Diagnostic` | set | `false` | Reserved; nothing reads it in this version |

## Versioning

| Name | Kind | Default | Meaning |
| --- | --- | --- | --- |
| `MSKit_VersionStrategy` | set | owner layer `ReleaseTag`; kit `SemVer` | `ReleaseTag`, `SemVer`, `SemVer4`, `DateBased`, `VersionTag`, `Manual` ([Versioning](../versioning.md#other-strategies)) |
| `MSKit_VersionTemplate`, `MSKit_StableVersionTemplate` | set | per strategy | Branch and stable-branch templates |
| `MSKit_ReleaseVersionTemplate`, `MSKit_PullRequestVersionTemplate` | set | `ReleaseTag`: `{releaseTag}`, `{prefix}-pr.{prNumber}.{buildNumber}` | Tag-build and pull-request templates |
| `MSKit_ExplicitVersion` | out | `Version` as it was before the kit loaded | When not empty the engine renders nothing |
| `MSKit_DeclaredVersionPrefix` | out | | `VersionPrefix` as declared, before a strategy default |
| `MSKit_IsReleaseTag` | set | `True` when `GITHUB_REF_TYPE=tag` | A tag build |
| `MSKit_ReleaseTagRaw`, `MSKit_ReleaseTag` | set | `GITHUB_REF_NAME`; the same without a leading `v` | |
| `MSKit_ReleaseTagRegex` | set | SemVer 2.0 | What a valid tag looks like |
| `MSKit_IsReleaseTagValid` | out | | |
| `MSKit_PullRequestNumber` | set | from `GITHUB_REF` / `GITHUB_REF_NAME` | `{prNumber}` |
| `MSKit_BuildDateTimeUtc` | set | the environment variable of that name, else each project's own clock | One date for a whole build |
| `MSKit_SkipAudit_ReleaseTagPrefix` | set | empty | `True` silences `MSKIT_VER007` |

## Target frameworks

| Name | Kind | Default | Meaning |
| --- | --- | --- | --- |
| `IsNET7`, `IsNET8`, `IsNET9`, `IsNET10`, `IsNET11`, `IsNET12`, `IsNET13`, `IsNET14` | out | | `True` for that `TargetFramework` ([constants](../build.md#target-framework-constants)) |
| `IsNET7_OR_GREATER`, `IsNET8_OR_GREATER`, `IsNET9_OR_GREATER`, `IsNET10_OR_GREATER`, `IsNET11_OR_GREATER`, `IsNET12_OR_GREATER`, `IsNET13_OR_GREATER`, `IsNET14_OR_GREATER` | out | | `True` for that version or later, up to `net14.0` |
| `IsNETSTANDARD20`, `IsNETSTANDARD21`, `IsNETSTANDARD` | out | | `netstandard2.0`, `netstandard2.1`, either |
| `IsNETFRAMEWORK`, `IsNETFRAMEWORK_OR_STANDARD` | out | | `net48`; `net48` or .NET Standard |
| `TargetFrameworkVersionMajor` | out | | `7` … `14` |
| `IsTfmConstantsImported` | out | | The constants file is loaded |
| `MSKit_TargetFramework_Shared`, `MSKit_TargetFrameworks_Shared` | out | | The value declared in `Directory.Build.props` ([declared once](../build.md#target-frameworks-declared-once)) |
| `MSKit_TargetFramework_Proj`, `MSKit_TargetFrameworks_Proj` | out | | The value declared in the csproj |
| `MSKit_SkipAudit_TargetFrameworkOverride` | set | empty | `True` accepts a different csproj value (`MSKIT_SHARED008` / `009`) |
| `MSKit_GuardXmlPeekRoutine`, `MSKit_GuardXmlPeekAudit` | set | empty (on) | `False` skips the text pre-check before parsing the csproj |

## Build defaults and reference checks

| Name | Kind | Default | Meaning |
| --- | --- | --- | --- |
| `MSKit_IncludeCodeAnalysisGlobalUsings` | set | `True` | The kit's [global usings](../build.md#global-usings) |
| `ExcludeFromCodeCoverage` | set | `True` for test projects | Adds `[ExcludeFromCodeCoverage]` to the assembly |
| `MSKit_TreatWarningsAsErrors_Shared` | out | | `TreatWarningsAsErrors` before the csproj body |
| `MSKit_SkipAudit_TreatWarningsAsErrors` | set | `True` on CI | Skips `MSKIT_SHARED020` |
| `MSKit_ImplicitPackageVersions` | set | `True` | The kit's [package versions](../build.md#central-package-versions) |
| `MSKit_SkipAudit_ImplicitPackageDuplicates` | set | `False` | `True` skips `MSKIT_DUP001` |
| `MSKit_RestrictPackageReference` | item | `Moq` (`Type="Error"`, owner layer) | A banned (`Type="Error"`) or discouraged (`Type="Warning"`) package, with a `Message` ([reference checks](../build.md#reference-checks)) |
| `MSKit_PackageReferenceNotAllowed`, `MSKit_ProjectReferenceNotAllowed` | item | | The checks' findings; read-only |
| `MSKit_RestrictReferences` | set | `False` | Allow-list mode for both reference kinds |
| `MSKit_RestrictProjectReferences`, `MSKit_RestrictPackageReferences` | set | `MSKit_RestrictReferences` | Allow-list mode for one kind (`Allowed="True"` required) |
| `MSKit_PrereleasePackagePrefix` | set | owner layer `DragoAnt.` | Ids the prerelease check covers |
| `MSKit_PrereleasePackageCheckAsWarning` | set | `true` | `false` makes `MSKIT_PRE001` an error |
| `MSKit_ProjectReferenceAsPrivateAssets`, `MSKit_PackageReferenceAsPrivateAssets` | set | empty | `True` makes every reference of that kind private ([Build](../build.md#private-references)) |
| `ManufacturerName`, `FullManufacturerName` | set | `DragoAnt` (owner layer, unconditional) | The owner ([Customizing](../customizing.md#the-owner-layer)) |

## Package versions

| Name | Kind | Default | Meaning |
| --- | --- | --- | --- |
| `MSKit_PackageVersion_XunitV3`, `MSKit_PackageVersion_XunitV3Assert`, `MSKit_PackageVersion_XunitV3ExtensibilityCore`, `MSKit_PackageVersion_XunitRunnerVisualStudio`, `MSKit_PackageVersion_MicrosoftNetTestSdk`, `MSKit_PackageVersion_MicrosoftTestingExtensionsTrxReport`, `MSKit_PackageVersion_MicrosoftTestingExtensionsCodeCoverage`, `MSKit_PackageVersion_AwesomeAssertions`, `MSKit_PackageVersion_FluentAssertions`, `MSKit_PackageVersion_Shouldly`, `MSKit_PackageVersion_NSubstitute`, `MSKit_PackageVersion_NSubstituteAnalyzersCSharp` | set | [Testing](../testing.md#package-versions) | The test stack's versions |
| `MSKit_PackageVersion_MicrosoftCodeAnalysis`, `MSKit_PackageVersion_MicrosoftCodeAnalysisAnalyzers` | set | [Roslyn](../roslyn.md#package-versions) | The Roslyn versions |

## Packaging

| Name | Kind | Default | Meaning |
| --- | --- | --- | --- |
| `IsPackable` | set | `True` (owner layer); `False` for test projects and code fixes | |
| `PackageIconPath` | set | `.toolkit/res/package.icon.png` (owner layer) | The icon (PNG or JPEG), packed as `icon<extension, lowercased>` |
| `MSKit_PackageIconSourcePath` | out | | The icon file the checks read |
| `MSKit_PackageReadmeSourcePath` | set | `package.readme.md`, else `README.md` next to the csproj | The README packed as `readme.md` |
| `MSKit_PackageValidationBaselineVersion` | set | empty | The release package validation compares against |
| `MSKit_DefaultReleaseNotes` | set | empty (on) | `False` turns the `PackageReleaseNotes` default off |
| `MSKit_PackageChecksAsErrors` | set | `True` on CI | The `MSKIT_PKG` checks as errors ([Packaging](../packaging.md#checks)) |
| `MSKit_SkipPackageChecks` | set | empty | Codes to skip, `;`-separated, or `All` |
| `MSKit_PackageDescriptionMinLength` | set | `30` | `MSKIT_PKG002` |
| `MSKit_PackageIconSize` | set | `128` | `MSKIT_PKG015` |
| `MSKit_SemVerRegex` | set | SemVer 2.0 | `MSKIT_PKG013` |

## Package readme

| Name | Kind | Default | Meaning |
| --- | --- | --- | --- |
| `MSKit_PackageReadmeFrom` | set | empty (off) | The README to generate from ([Package readme](../package-readme.md#properties)) |
| `MSKit_GeneratedPackageReadmePath` | set | `obj/<Configuration>/package.readme.md` | Where the generated file goes |
| `MSKit_PackageReadmeTitle` | set | `auto` (the `PackageId`) | The first level-1 heading; empty keeps the README's |
| `MSKit_RepoProvider` | set | detected | `GitHub`, `GitLab`, `AzureDevOps`, `Bitbucket`, `Gitea` |
| `MSKit_RepoBlobUrlTemplate`, `MSKit_RepoRawUrlTemplate` | set | the provider's | File-link and image templates |
| `MSKit_ReleasesUrl`, `MSKit_IssuesUrl` | set | `auto` | The links added to the overview; empty leaves one out |
| `MSKit_RepositoryVisibility` | set | `CI_PROJECT_VISIBILITY` | `private` / `internal` raises `MSKIT_PKG022` |
| `MSKit_PackageReadmeAllowedImageHosts` | set | the hosts file | `;`-separated hosts that replace the file's list |
| `MSKit_PackageReadmeAllowedImageHostsFile` | set | the kit's `nuget.allowed-image-hosts.txt` | The hosts file |

## Testing

| Name | Kind | Default | Meaning |
| --- | --- | --- | --- |
| `IsTestsProject`, `IsTestsLibProject` | out | from the name | A test project, a test helper library ([Testing](../testing.md#which-projects-are-test-projects)); set `IsTestsLibProject` directly if you like, never `IsTestsProject` |
| `MSKit_TestsProjectNameRegex` | set | `\.(Tests(\.Integration\|\.Unit)?\|IntegrationTests\|UnitTests)$` | Test-project names |
| `MSKit_TestsLibProjectNameRegex` | set | `\.(TestsSuite\|TestsFixtures\|Fixtures)$` | Helper-library names |
| `MSKit_DisableTestsProjectAutoDetect`, `MSKit_DisableTestsLibProjectAutoDetect` | set | empty | `true` turns detection off |
| `MSKit_IsTestsProjectAutoDetected`, `MSKit_IsTestsLibProjectAutoDetected` | out | | The name matched |
| `TestsProjectCommonPropsPath`, `TestsLibProjectCommonPropsPath` | out | | The explicit endpoints to `Import` |
| `MSKit_TestingFramework` | set | `xunit.v3` (owner layer) | The framework wiring |
| `MSKit_TestingFrameworkAttached` | out | | An installed part wires the framework |
| `MSKit_TestingFramework_CommonPropsPath`, `MSKit_TestingFramework_LibCommonPropsPath` | set | the installed part's | Your own wiring for another framework |
| `MSKit_TestsAssertions` | set | `AwesomeAssertions` | `AwesomeAssertions`, `FluentAssertions`, `Shouldly`, `None` |
| `MSKit_TestsMocking` | set | `NSubstitute` | `NSubstitute`, `None` |
| `MSKit_TestsImplicitReferences` | set | empty (on) | `False` leaves the assertion and mocking references out |
| `InternalsVisibleToAllTestsProjects` | set | `True` for non-test projects | [`InternalsVisibleTo`](../testing.md#internalsvisibleto) to every test project |
| `MSKit_TestsDir` | set | the solution folder | Where test projects are looked for |
| `MSKit_ScaffoldTestConfig` | set | empty | `True` writes starter `testconfig.json` / `xunit.runner.json` |
| `MTPTestConfigFileName`, `XunitRunnerConfigFileName` | set | `testconfig.json`, `xunit.runner.json` | Config files copied to the output |

## Roslyn components

| Name | Kind | Default | Meaning |
| --- | --- | --- | --- |
| `IsCodeAnalyzer`, `IsCodeFixer`, `IsSourceGenerator` | set | from the name | The role ([Roslyn](../roslyn.md#wiring-a-project)) |
| `IsRoslynComponent` | out | `True` in a Roslyn project | |
| `MSKit_CodeAnalyzerProjectNameRegex`, `MSKit_CodeFixerProjectNameRegex`, `MSKit_SourceGeneratorProjectNameRegex` | set | `\.Analyzers$`, `\.CodeFixes$`, `\.SourceGenerator$` | Role names |
| `MSKit_DisableCodeAnalyzerAutoDetect`, `MSKit_DisableCodeFixerAutoDetect`, `MSKit_DisableSourceGeneratorAutoDetect` | set | empty | `true` above the kit import turns detection off |
| `MSKit_IsCodeAnalyzerAutoDetected`, `MSKit_IsCodeFixerAutoDetected`, `MSKit_IsSourceGeneratorAutoDetected` | out | | The name matched |
| `MSKit_AutoDetectedProjectType` | item | | Every role the name matched; more than one is `MSKIT_CORE001` |
| `MSKit_CodeAnalyzerSatelliteAttached`, `MSKit_CodeFixerSatelliteAttached`, `MSKit_SourceGeneratorSatelliteAttached` | out | | The role's part is installed |
| `CodeAnalyzerCommonPropsPath`, `CodeFixerCommonPropsPath`, `SourceGeneratorCommonPropsPath`, `RoslynComponentCommonPropsPath` | out | | The props a Roslyn project imports |
| `MSKit_HasCodeFixer` | set | `True` | Look for the sibling code-fix project |
| `MSKit_CodeFixer` | set | `../<Name>.CodeFixes/<Name>.CodeFixes.csproj` | The code-fix project packed with the analyzer |
| `IncludeGenerateResultToProject`, `GenerateResultOutputPath` | set | empty, `_generated` | Write generated sources into the project |

## Local files and secrets

| Name | Kind | Default | Meaning |
| --- | --- | --- | --- |
| `MSKit_LocalSecretsBaseDirectory` | set | the user-secrets folder | ([Local files](../local-files.md)) |
| `LocalSecretsDir` | set | `<base>/<UserSecretsId>` | A project's local folder |
| `LocalSecrets`, `LocalSecretsTemplate`, `LocalSecretsTemplateDir` | out | | `secrets.json` and its template |
| `UserSecretsLinkNamePrefix` | set | `appsettings` | The linked name, `<prefix>.UserSecrets.json` |
| `MSKit_SecretsCleanUp` | set | `True` on CI | Delete `secrets.json` |
| `MSKit_CopyUserSecretsIdToOutput`, `MSKit_CopyUserSecretsIdToPublish` | set | empty | `true` copies `secrets.json` to the build / publish output |
| `MSKit_CopySecretsToProject`, `CopySecretsToProjectFileName` | set | `false`, empty | Copy `secrets.json` into the project folder (replaces its `.gitignore`) |
| `MSKit_SlnSecretsId` | set | `MSKit_SlnFileName` | The solution's folder under the user-secrets folder |
| `MSKit_UseSlnSecretsProps`, `MSKit_UseSlnSecretsTargets` | set | `False` | Import `Directory.Secrets.props` / `.targets` |
| `LocalSlnSecretsDir`, `LocalSlnSecretsProps`, `LocalSlnSecretsTargets` | out | | Their paths |
| `MSKit_SlnSecretsCleanUp` | set | `True` on CI | Delete them |
| `LocalCompileTemplateDir` | set | `<MSKit_Templates>LocalCompile/` | Templates for `LocalCompile` items |

## Optional parts

| Name | Kind | Default | Meaning |
| --- | --- | --- | --- |
| `PackageAsProj_SkipChecks` | set | empty | `True` skips `MSKIT_PAP002` ([PackageAsProj](../optional-parts.md#packageasproj)) |
| `ProjMetadataOutDir` | set | empty (off) | Where the metadata YAML goes ([ProjMetadata](../optional-parts.md#projmetadata)) |
| `MSKit_EFScriptsDir` | out | | The EF scripts folder ([EF](../optional-parts.md#ef)) |

# Migrating from MSBuild.Routine

[MSBuild.Routine](https://github.com/DragoAnt/MSBuild.Routine) is the older, submodule-based predecessor of the kit. Moving a repository over:

1. **Remove the submodule:** `git rm .msbuild`, delete `.gitmodules`, and drop `submodules:` from your workflows.
2. **Install the kit** ([Getting started](./getting-started.md)), with `--add PackageAsProj` if you use `Directory.PackageAsProj.targets`, and replace the `.msbuild\shared\init.props` / `init.targets` imports with the `.toolkit/msbuild/` ones.
3. **Drop what is now a default:** `Copyright`, `PackageLicenseExpression`, `RepositoryUrl`, `PackageReleaseNotes`, `TargetFrameworkStrategy`, and the `.msbuild\tfm.constants.props` import.
4. **Remove the versions the kit provides** from `Directory.Packages.props` (`xunit.v3*`, `xunit.runner.visualstudio`, `Microsoft.NET.Test.Sdk`, `Microsoft.Testing.Extensions.CodeCoverage`, `NSubstitute*`, your assertion library, `coverlet.collector`) and the explicit `Microsoft.Testing.Extensions.CodeCoverage` references from test projects; [`MSKITDUP001`](./reference/codes.md#mskitdup001) lists any you missed. To keep FluentAssertions 7, set `MSKit_TestsAssertions=FluentAssertions`.
5. **Add `Directory.Version.props`** with the next `VersionPrefix`, and publish releases with tags such as `v2.0.1` ([Versioning](./versioning.md)).

Renamed properties:

| MSBuild.Routine | MSBuildKit |
| --- | --- |
| `IncrementVersionType` | `MSKit_VersionStrategy` |
| `IsDevEnv`, `Branch`, `BuildNumber`, `CommitSha` | `MSKit_IsDevEnv`, `MSKit_Branch`, `MSKit_BuildNumber`, `MSKit_CommitSha` |
| `SlnSecretsId`, `SecretsTemplatesDir` | `MSKit_SlnSecretsId`, `MSKit_Templates` |
| `TestsDir` | `MSKit_TestsDir` |
| `SkipCheck_*` | `MSKit_SkipAudit_*` |
| `IsCodeAnalizerLib` | the `Project.CodeAnalyzer` part (`*.Analyzers` projects that import `$(CodeAnalyzerCommonPropsPath)`, [Roslyn](./roslyn.md)) |

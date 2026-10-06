# Troubleshooting

Symptoms, their cause, and the fix. A build message with an `MSKIT_` code is explained in the [code reference](./reference/codes.md).

## Updating

| Symptom | Cause | Fix |
| --- | --- | --- |
| `update.sh` stops with `syntax error` or `unexpected EOF`; `kit.json` still names the old version | an update started from 0.2.0 or earlier runs the old script, which the new copy overwrites while it runs | run the same command once more |
| `SHA-256 mismatch … expected … (kit.json or --sha256)` | the release zip differs from the one pinned in `kit.json` for the same version | find out why the release changed before installing; `--sha256` with the new hash accepts it |
| `update.sh` without `--version` installs the version you already have | it reinstalls the pinned version | pass `--version <x.y.z>` ([Install and update](./install-and-update.md)) |
| `'<Part>' is a default part and cannot be removed` | default parts are always installed | — |

## Building

| Symptom | Cause | Fix |
| --- | --- | --- |
| Many [`MSKIT_DUP001`](./reference/codes.md#mskitdup001) errors right after installing | `Directory.Packages.props` repeats versions the kit provides | delete those `PackageVersion` lines, or override the kit's `MSKit_PackageVersion_*` property ([Build](./build.md#central-package-versions)) |
| The version is `9999.0.0` | a developer-machine build (no `GITHUB_RUN_ID`) | expected; `-p:MSKit_IsDevEnv=False` builds as CI ([Versioning](./versioning.md)) |
| `dotnet msbuild -getProperty:Version` prints `unknown placeholder: …` | a version template uses a placeholder the engine does not know | fix the template; a real build stops with [`MSKIT_VER002`](./reference/codes.md#mskitver002) |
| Restore fails on a tag build with [`MSKIT_VER006`](./reference/codes.md#mskitver006) | the tag is not a SemVer 2.0 version | delete the tag and the release, tag again (`v2.1.0`, `v2.1.0-beta.1`) |
| [`MSKIT_SHARED006`](./reference/codes.md#mskitshared006) / [`007`](./reference/codes.md#mskitshared007) after moving `TargetFrameworks` to `Directory.Build.props` | the csproj still repeats the value | delete it from the csproj |
| [`MSKIT_SHARED020`](./reference/codes.md#mskitshared020) locally, but CI is green | a csproj changes `TreatWarningsAsErrors`; the check runs on developer machines only | align the csproj, or set `MSKit_SkipAudit_TreatWarningsAsErrors=True` |
| [`MSKIT_ROSLYN001`](./reference/codes.md#mskitroslyn001)-`003` on a project that is not a Roslyn component | its name ends in `.Analyzers`, `.CodeFixes` or `.SourceGenerator` | rename it, or set `MSKit_Disable<Role>AutoDetect=true` in `Directory.Build.props` above the kit import ([Roslyn](./roslyn.md#wiring-a-project)) |
| An `*.Analyzers` project builds for the shared target frameworks and references no Roslyn package | the role's props are not imported | add `<Import Project="$(CodeAnalyzerCommonPropsPath)" />` ([Roslyn](./roslyn.md#wiring-a-project)) |
| `IsNET8` is empty in a csproj `PropertyGroup` of a single-framework project | the constants are known in the props phase only for multi-targeted inner builds | test them in item and target conditions or in `Directory.Build.targets` ([Build](./build.md#target-framework-constants)) |

## Testing

| Symptom | Cause | Fix |
| --- | --- | --- |
| [`MSKIT_TEST013`](./reference/codes.md#mskittest013) | the csproj sets `IsTestsProject` | rename the project to `*.Tests`, or use `$(TestsProjectCommonPropsPath)` ([Testing](./testing.md#which-projects-are-test-projects)) |
| `dotnet test` on SDK 10 rejects `--solution`, `--coverage` or `--report-trx` | without the runner in `global.json` it runs in VSTest mode | add `"test": { "runner": "Microsoft.Testing.Platform" }` ([Microsoft.Testing.Platform mode](https://learn.microsoft.com/dotnet/core/testing/unit-testing-with-dotnet-test)) |
| NSubstitute cannot mock an internal type | the project under test is not exposing internals | keep `InternalsVisibleToAllTestsProjects` on and the test project under `MSKit_TestsDir` ([Testing](./testing.md#internalsvisibleto)) |

## Packing

| Symptom | Cause | Fix |
| --- | --- | --- |
| `dotnet pack` passes locally and fails on CI with `MSKIT_PKG` errors | the checks are warnings on a developer machine and errors on CI | fix the warnings the local pack prints ([Packaging](./packaging.md#checks)) |
| [`MSKIT_PKG016`](./reference/codes.md#mskitpkg016) on GitHub Enterprise, GitLab or another host | the release-notes default exists only for `github.com` | set `PackageReleaseNotes`, or generate the readme with `MSKit_PackageReadmeFrom` ([Package readme](./package-readme.md)) |
| [`MSKIT_PKG021`](./reference/codes.md#mskitpkg021) for every image of a self-hosted GitLab | nuget.org shows images only from its allowed hosts | host the images elsewhere, or point `MSKit_RepoRawUrlTemplate` at an allowed host |

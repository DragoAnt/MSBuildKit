# Testing

The Testing and Testing.XUnit.v3 parts turn a project into a test project by its name: [Microsoft.Testing.Platform](https://learn.microsoft.com/dotnet/core/testing/microsoft-testing-platform-intro) v2, [xUnit v3](https://xunit.net/docs/getting-started/v3/microsoft-testing-platform), code coverage and TRX reports, an assertion library, [NSubstitute](https://nsubstitute.github.io/), and `InternalsVisibleTo` from the code under test. A test project only references what it tests.

## Which projects are test projects

| Kind | Name matches | Becomes |
| --- | --- | --- |
| test project | `MSKit_TestsProjectNameRegex`, default `\.(Tests(\.Integration\|\.Unit)?\|IntegrationTests\|UnitTests)$`: `Acme.Tests`, `Acme.Tests.Unit`, `Acme.Tests.Integration`, `Acme.UnitTests`, `Acme.IntegrationTests` | `IsTestsProject=True`: an executable test host, never packable |
| test helper library | `MSKit_TestsLibProjectNameRegex`, default `\.(TestsSuite\|TestsFixtures\|Fixtures)$` | `IsTestsLibProject=True`: shared fixtures and base classes with the assertion and xUnit libraries, not runnable |

Detection runs in the props phase, because the test framework's own targets read the result before `Directory.Build.targets`. So a project whose name does not match cannot just set `IsTestsProject` in its csproj — that fails with [`MSKITTEST013`](./reference/codes.md#mskittest013). Use the explicit endpoint instead:

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <MSKit_TestingFramework>xunit.v3</MSKit_TestingFramework>
  </PropertyGroup>
  <Import Project="$(TestsProjectCommonPropsPath)" />
</Project>
```

`$(TestsLibProjectCommonPropsPath)` does the same for a helper library; a helper library may also set `IsTestsLibProject=True` directly. Override either regex in `Directory.Build.props`, or switch detection off with `MSKit_DisableTestsProjectAutoDetect=true` / `MSKit_DisableTestsLibProjectAutoDetect=true`.

## What a test project gets

- **Runner:** `OutputType=Exe`, `EnableMicrosoftTestingPlatform=True`, `xunit.v3.mtp-v2`, [`Microsoft.Testing.Extensions.CodeCoverage`](https://learn.microsoft.com/dotnet/core/testing/microsoft-testing-platform-extensions-code-coverage) and [`Microsoft.Testing.Extensions.TrxReport`](https://learn.microsoft.com/dotnet/core/testing/microsoft-testing-platform-extensions-test-reports). On net8.0 and net9.0 `TestingPlatformDotnetTestSupport=True` bridges SDK 8/9 `dotnet test` to it. `EnableMicrosoftTestingPlatform=False` falls back to [VSTest](https://learn.microsoft.com/dotnet/core/testing/unit-testing-platform-vs-vstest) (`Microsoft.NET.Test.Sdk`, `xunit.runner.visualstudio`, `xunit.v3`).
- **Exit code:** `TestingPlatformCommandLineArguments` defaults to `--ignore-exit-code 8`, so a project whose tests are all skipped does not fail the run.
- **Libraries:** the assertion library of `MSKit_TestsAssertions` and the mocking library of `MSKit_TestsMocking`, as package references with global usings, plus `global using Xunit` and `System.Diagnostics.CodeAnalysis`. `MSKit_TestsImplicitReferences=False` leaves all of them out.
- **Coverage:** `ExcludeFromCodeCoverage=True`, so the test assembly itself is not counted.
- **Config files:** `testconfig.json` (`MTPTestConfigFileName`) and `xunit.runner.json` (`XunitRunnerConfigFileName`) next to the csproj are copied to the output. `MSKit_ScaffoldTestConfig=True` writes starter files on a developer build when they are missing.

| Property | Default | Values |
| --- | --- | --- |
| `MSKit_TestingFramework` | `xunit.v3` | `xunit.v3`, or your own wiring through `MSKit_TestingFramework_CommonPropsPath` / `MSKit_TestingFramework_LibCommonPropsPath` |
| `MSKit_TestsAssertions` | `AwesomeAssertions` | [`AwesomeAssertions`](https://awesomeassertions.org/), [`FluentAssertions`](https://fluentassertions.com/) (pinned to `[7.2.2]`, the last version under the Apache licence), [`Shouldly`](https://docs.shouldly.org/), `None` |
| `MSKit_TestsMocking` | `NSubstitute` | `NSubstitute` (with [NSubstitute.Analyzers](https://github.com/nsubstitute/NSubstitute.Analyzers)), `None` |

## Running

Add the runner to `global.json` (`"test": { "runner": "Microsoft.Testing.Platform" }`), then:

```sh
dotnet test --solution MyRepo.slnx -c Release --coverage --coverage-output-format cobertura --report-trx --report-xunit-junit --results-directory TestResults
```

`--coverage` comes from the code-coverage extension, `--report-trx` from the TRX extension, `--report-xunit-junit` from xUnit itself.

## `InternalsVisibleTo`

Every project that is neither a test project nor a helper library exposes its internals to **every** test project and helper library found under `MSKit_TestsDir` (default: the solution folder, else the git root), and to `DynamicProxyGenAssembly2`, so NSubstitute can mock internal types. `InternalsVisibleToAllTestsProjects=False` in a csproj turns it off for that project. [`MSKITTEST030`](./reference/codes.md#mskittest030) and [`MSKITTEST031`](./reference/codes.md#mskittest031) warn when `MSKit_TestsDir` is empty or missing.

## Package versions

The kit provides these versions ([Build](./build.md#central-package-versions)); override one with its property:

| Package | Property | Version |
| --- | --- | --- |
| `xunit.v3`, `xunit.v3.mtp-v2` | `MSKit_PackageVersion_XunitV3` | `4.0.1` |
| `xunit.v3.assert` | `MSKit_PackageVersion_XunitV3Assert` | `MSKit_PackageVersion_XunitV3` |
| `xunit.v3.extensibility.core` | `MSKit_PackageVersion_XunitV3ExtensibilityCore` | `MSKit_PackageVersion_XunitV3` |
| `xunit.runner.visualstudio` | `MSKit_PackageVersion_XunitRunnerVisualStudio` | `4.0.0` |
| `Microsoft.NET.Test.Sdk` | `MSKit_PackageVersion_MicrosoftNetTestSdk` | `18.10.1` |
| `Microsoft.Testing.Extensions.TrxReport` | `MSKit_PackageVersion_MicrosoftTestingExtensionsTrxReport` | `2.4.1` |
| `Microsoft.Testing.Extensions.CodeCoverage` | `MSKit_PackageVersion_MicrosoftTestingExtensionsCodeCoverage` | `18.11.2` |
| `AwesomeAssertions` | `MSKit_PackageVersion_AwesomeAssertions` | `9.6.0` |
| `FluentAssertions` | `MSKit_PackageVersion_FluentAssertions` | `[7.2.2]` |
| `Shouldly` | `MSKit_PackageVersion_Shouldly` | `4.3.0` |
| `NSubstitute` | `MSKit_PackageVersion_NSubstitute` | `6.2.0` |
| `NSubstitute.Analyzers.CSharp` | `MSKit_PackageVersion_NSubstituteAnalyzersCSharp` | `1.0.17` |

## Checks

| Code | When |
| --- | --- |
| [`MSKITTEST005`](./reference/codes.md#mskittest005) | an xUnit v3 test project targets a framework older than net8.0 |
| [`MSKITTEST010`](./reference/codes.md#mskittest010)-[`012`](./reference/codes.md#mskittest012), [`MSKITTEST020`](./reference/codes.md#mskittest020)-[`022`](./reference/codes.md#mskittest022) | the explicit endpoint was imported before `MSKit_TestingFramework` was set, the framework changed after it, or no wiring exists for it |
| [`MSKITTEST013`](./reference/codes.md#mskittest013) | a csproj sets `IsTestsProject` directly |
| [`MSKITTEST014`](./reference/codes.md#mskittest014) | a project named like a test project is marked as a helper library |
| [`MSKITTEST025`](./reference/codes.md#mskittest025), [`MSKITTEST026`](./reference/codes.md#mskittest026) | a test project has no `MSKit_TestingFramework`, or no installed part wires it |

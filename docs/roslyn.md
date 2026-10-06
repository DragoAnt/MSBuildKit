# Roslyn components

Four optional parts build [Roslyn](https://github.com/dotnet/roslyn) analyzers, code fixes and source generators and pack them the way the compiler loads them. Install the ones you need; each brings the parts it requires:

```sh
sh .toolkit/update.sh --add Project.CodeAnalyzer --add Project.CodeFixer --add Project.SourceGenerator
```

## Wiring a project

A project needs **both** of these:

1. **Its name**, which sets the role: `*.Analyzers` → `IsCodeAnalyzer`, `*.CodeFixes` → `IsCodeFixer`, `*.SourceGenerator` → `IsSourceGenerator` (`MSKit_CodeAnalyzerProjectNameRegex`, `MSKit_CodeFixerProjectNameRegex`, `MSKit_SourceGeneratorProjectNameRegex`). The role turns on the packing targets.
2. **An import of the role's props**, which sets the target framework, the Roslyn references and the package shape. The kit does not import it for you:

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <Import Project="$(CodeAnalyzerCommonPropsPath)" />
  <PropertyGroup>
    <Description>Analyzers that catch misuse of the Acme masking API at compile time.</Description>
  </PropertyGroup>
</Project>
```

| Project | Import |
| --- | --- |
| analyzer (`Acme.Analyzers`) | `$(CodeAnalyzerCommonPropsPath)` |
| code fix (`Acme.CodeFixes`) | `$(CodeFixerCommonPropsPath)` |
| source generator (`Acme.SourceGenerator`) | `$(SourceGeneratorCommonPropsPath)` |

The analyzer and code-fix props set their role themselves, so a project with another name only needs the import; a source generator with another name also sets `<IsSourceGenerator>true</IsSourceGenerator>` above it. Set your own `Description`: the analyzer's default, "Code analyzers description", fails [`MSKIT_PKG002`](./reference/codes.md#mskitpkg002).

A project whose name matches a role but whose part is not installed fails with [`MSKIT_ROSLYN001`](./reference/codes.md#mskitroslyn001)-[`003`](./reference/codes.md#mskitroslyn003); a name that matches two roles fails with [`MSKIT_CORE001`](./reference/codes.md#mskitcore001). Detection runs in the props phase, so to stop it set `MSKit_Disable<Role>AutoDetect=true` (`MSKit_DisableCodeAnalyzerAutoDetect`, …) or narrow the regex, in `Directory.Build.props` above the kit import; set in the csproj, as the error text suggests, it comes too late.

## What the props set

Every role (`$(RoslynComponentCommonPropsPath)`, imported by the three above):

| Setting | Value |
| --- | --- |
| `TargetFramework` | `netstandard2.0` (a shared `TargetFrameworks` is cleared, and the `MSKIT_SHARED008` override warning is skipped) |
| `IsRoslynComponent`, `EnforceExtendedAnalyzerRules`, `DevelopmentDependency` | `True` |
| `IsPackable` | `True` |
| `IncludeBuildOutput`, `IncludeSymbols` | `False`: the dll goes to `analyzers/dotnet/cs/`, not `lib/` |
| `NoPackageAnalysis` | `True` |
| `NoWarn` | adds `RS1036` |
| `PackageTags` | `roslyn;code-analysis` |
| references | `Microsoft.CodeAnalysis.Common`, `Microsoft.CodeAnalysis.CSharp` (private) |

| Role | Adds |
| --- | --- |
| analyzer | `PackageTags` `analyzer`; packs the dll, its PDB and `AnalyzerReleases.Shipped.md` / `.Unshipped.md` (when present) into `analyzers/dotnet/cs/`; packs the sibling code-fix dll into the same package |
| code fix | `IsPackable=False` (it ships inside the analyzer's package); `Microsoft.CodeAnalysis.Workspaces.Common` |
| source generator | `PackageTags` `source-generator`; `Microsoft.CodeAnalysis.Analyzers`; packs the dll and PDB into `analyzers/dotnet/cs/` |

Analyzer and source-generator projects get no [global usings](./build.md#global-usings). The analyzer never references `Workspaces` — that would trip RS1038 from [Microsoft.CodeAnalysis.Analyzers](https://github.com/dotnet/roslyn-analyzers) — which is why code fixes live in their own project.

## Analyzer and code fix in one package

An analyzer named `Acme.Analyzers` looks for `../Acme.CodeFixes/Acme.CodeFixes.csproj` and packs its dll next to its own. `MSKit_CodeFixer` points at another project; `MSKit_HasCodeFixer=False` turns the lookup off. There is deliberately no `ProjectReference` between the two (NuGet would reject the cycle), so build the solution before packing with `--no-build`.

## Using an analyzer from the same repository

A `ProjectReference` with `IsAnalyzer="True"` is turned into an analyzer reference (`OutputItemType="Analyzer"`, `ReferenceOutputAssembly="false"`):

```xml
<ProjectReference Include="../Acme.Analyzers/Acme.Analyzers.csproj" IsAnalyzer="True" />
```

## Seeing generated code

A source generator project with `IncludeGenerateResultToProject=true` writes the generated files to `_generated/` in the project (`GenerateResultOutputPath`) and keeps them out of the compile, so they can be committed and reviewed.

## Package versions

| Packages | Property | Version |
| --- | --- | --- |
| `Microsoft.CodeAnalysis.Common`, `.CSharp`, `.Workspaces.Common` | `MSKit_PackageVersion_MicrosoftCodeAnalysis` | `4.14.0` — loads in the .NET 9.0.300 and .NET 10 SDK compilers and Visual Studio 17.14+; a newer one fails to load in older compilers |
| `Microsoft.CodeAnalysis.Analyzers` | `MSKit_PackageVersion_MicrosoftCodeAnalysisAnalyzers` | `3.11.0` |

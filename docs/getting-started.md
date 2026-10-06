# Getting started

From an empty repository to a packed library with passing tests. You need the [.NET SDK](https://dotnet.microsoft.com/download) 8 or later (the kit's own CI uses 10), and `sh` (Git Bash on Windows) or [PowerShell 7](https://learn.microsoft.com/powershell/scripting/install/installing-powershell).

## 1 Install

From the repository root:

```sh
curl -fsSLO https://github.com/DragoAnt/MSBuildKit/releases/latest/download/update.sh
sh update.sh && rm update.sh
```

```powershell
Invoke-WebRequest https://github.com/DragoAnt/MSBuildKit/releases/latest/download/update.ps1 -OutFile update.ps1
pwsh ./update.ps1; Remove-Item update.ps1
```

The script downloads the latest release, checks its SHA-256, and writes:

| Path | What |
| --- | --- |
| `.toolkit/msbuild/` | the kit: one folder per [part](./parts.md) and the `init.props` / `init.targets` entry points |
| `.toolkit/res/package.icon.png` | the package icon |
| `.toolkit/kit.json` | the pinned version, its SHA-256 and your optional parts |
| `.toolkit/kit.parts`, `.toolkit/update.sh`, `.toolkit/update.ps1` | the part list and the update scripts |
| `Directory.Build.props`, `Directory.Build.targets` | only when missing: one import each |

If the two `Directory.Build.*` files already exist, the script prints the line each needs instead of editing them:

```xml
<!-- Directory.Build.props -->
<Import Project="$(MSBuildThisFileDirectory).toolkit/msbuild/init.props" />
<!-- Directory.Build.targets -->
<Import Project="$(MSBuildThisFileDirectory).toolkit/msbuild/init.targets" />
```

Commit `.toolkit/` with the rest of the repository: the kit is reviewed like any other change. [Install and update](./install-and-update.md) has every option.

## 2 Declare the next version

Next to `Directory.Build.props`, create `Directory.Version.props`:

```xml
<Project>
  <PropertyGroup>
    <VersionPrefix>1.4.0</VersionPrefix>
  </PropertyGroup>
</Project>
```

`VersionPrefix` is the version the repository will release next. Release builds take their version from the tag, branch and pull-request builds from this prefix ([Versioning](./versioning.md)).

## 3 Set the test runner

Tests run on [Microsoft.Testing.Platform](https://learn.microsoft.com/dotnet/core/testing/microsoft-testing-platform-intro). Tell `dotnet test` in `global.json`:

```json
{
  "sdk": { "version": "10.0.100", "rollForward": "latestFeature" },
  "test": { "runner": "Microsoft.Testing.Platform" }
}
```

## 4 Projects

A library needs a description and tags, nothing else; licence, icon, README, Source Link and symbols come from the kit:

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFrameworks>net8.0;net10.0</TargetFrameworks>
    <Description>What the package does and what sets it apart, in one or two sentences.</Description>
    <PackageTags>json;masking;logging</PackageTags>
  </PropertyGroup>
</Project>
```

Add a `package.readme.md` next to it, or generate every readme from the repository README ([Package readme](./package-readme.md)).

A project whose name ends in `.Tests` is a test project: [xUnit v3](https://xunit.net/), an assertion library, [NSubstitute](https://nsubstitute.github.io/) and coverage are wired in, so it only references the code it tests:

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <ItemGroup>
    <ProjectReference Include="../../src/Acme.Masking/Acme.Masking.csproj" />
  </ItemGroup>
</Project>
```

With [central package management](https://learn.microsoft.com/nuget/consume-packages/central-package-management), leave the test packages out of `Directory.Packages.props`: the kit provides their versions ([`MSKITDUP001`](./reference/codes.md#mskitdup001) reports a duplicate).

## 5 Build, test, pack

```sh
dotnet build MyRepo.slnx -c Release
dotnet test --solution MyRepo.slnx -c Release --coverage --coverage-output-format cobertura --report-trx --report-xunit-junit --results-directory TestResults
dotnet pack MyRepo.slnx -c Release -o artifacts
```

On your machine the version is `9999.0.0` and the package checks are warnings; on GitHub Actions the version comes from the run ([Versioning](./versioning.md)) and the checks are errors ([Packaging](./packaging.md)).

## A complete example

[`samples/MinimalLibrary`](../samples/MinimalLibrary) is a repository with one library and one test project that passes every check; the kit's self-test installs the kit into it and builds, tests and packs it on Linux and Windows.

## Next

- [Parts](./parts.md): what is installed and how to add an optional part.
- [Customizing](./customizing.md): another owner name, your own files around the kit, a default you want changed.
- [Troubleshooting](./troubleshooting.md) when a build or an update fails.

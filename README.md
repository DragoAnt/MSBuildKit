# DragoAnt.MSBuildKit

Shared MSBuild settings for .NET repositories that publish NuGet packages: nuget.org-ready package metadata with build-time checks, versions from release tags, and [Microsoft.Testing.Platform](https://learn.microsoft.com/dotnet/core/testing/microsoft-testing-platform-intro) tests with coverage. Installed as plain files you can read and review, updated by one script.

[![CI](https://img.shields.io/github/actions/workflow/status/DragoAnt/MSBuildKit/ci.yml?branch=main)](https://github.com/DragoAnt/MSBuildKit/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/DragoAnt/MSBuildKit)](https://github.com/DragoAnt/MSBuildKit/releases)
[![License](https://img.shields.io/github/license/DragoAnt/MSBuildKit)](./LICENSE)

## Key features

- **Packages that pass nuget.org's rules by default.** Licence, icon, README, [Source Link](https://learn.microsoft.com/dotnet/standard/library-guidance/sourcelink), symbols, repository and release-notes links, [package validation](https://learn.microsoft.com/dotnet/fundamentals/apicompat/package-validation/overview) and [NuGet audit](https://learn.microsoft.com/nuget/concepts/auditing-packages); nineteen `MSKITPKG` checks run on `dotnet pack`, warnings on your machine and errors on CI. [Packaging](./docs/packaging.md)
- **One README for the repository and its packages.** `MSKit_PackageReadmeFrom=README.md` generates each package's readme on pack, with links pinned to the commit. [Package readme](./docs/package-readme.md)
- **Versions from release tags.** Tag `v1.4.0` and the packages are `1.4.0`; branch builds are `1.4.0-ci.<run>`, pull requests `1.4.0-pr.<n>.<run>`, local builds `9999.0.0`. [Versioning](./docs/versioning.md)
- **Tests on Microsoft.Testing.Platform v2.** Projects named `*.Tests` become [xUnit v3](https://xunit.net/docs/getting-started/v3/microsoft-testing-platform) test projects with coverage, TRX and JUnit reports, an assertion library and [NSubstitute](https://nsubstitute.github.io/). [Testing](./docs/testing.md)
- **Build checks that keep a repository consistent.** Target frameworks declared once, banned packages, prerelease dependencies on a stable branch, `TreatWarningsAsErrors` drift. [Build defaults and checks](./docs/build.md)
- **Plain files, one update script.** The kit lives in your repository's `.toolkit/` folder, so every change shows up in a pull request; `update.sh` / `update.ps1` install a release after checking its SHA-256. It is not a NuGet package or an MSBuild SDK: nothing is restored at build time. [Install and update](./docs/install-and-update.md)

## Install

From the repository root, with a POSIX shell or PowerShell 7:

```sh
curl -fsSLO https://github.com/DragoAnt/MSBuildKit/releases/latest/download/update.sh
sh update.sh && rm update.sh
```

```powershell
Invoke-WebRequest https://github.com/DragoAnt/MSBuildKit/releases/latest/download/update.ps1 -OutFile update.ps1
pwsh ./update.ps1; Remove-Item update.ps1
```

Then declare the next version in `Directory.Version.props` and commit `.toolkit/`. [Getting started](./docs/getting-started.md) walks through the first build, test and pack; [`samples/MinimalLibrary`](./samples/MinimalLibrary) is a complete repository with every check passing.

## Documentation

[docs/README.md](./docs/README.md) lists the pages in reading order. Every property is in the [property reference](./docs/reference/properties.md), every warning and error in the [code reference](./docs/reference/codes.md). Coming from MSBuild.Routine: [migration guide](./docs/migrating-from-msbuild-routine.md).

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md). Changes are listed in [CHANGELOG.md](./CHANGELOG.md).

## License

[MIT](./LICENSE)

# Parts

The kit is split into parts, one folder each under `.toolkit/msbuild/` (`DragoAnt.MSBuildKit.<Part>`; the trunk is `DragoAnt.MSBuildKit`). Default parts are always installed; optional ones are added with `update.sh --add <Part>` and recorded in `kit.json` ([Install and update](./install-and-update.md)). The list lives in `.toolkit/kit.parts`.

| Part | Installed | Requires | What it does | Page |
| --- | --- | --- | --- | --- |
| `Core` | default | | Developer machine or CI, solution and git roots, branch, `TargetFramework` / `TargetFrameworks` switching, Roslyn project-type detection | [Build](./build.md) |
| `Trunk` | default | | Language defaults, product and copyright, the version engine, global usings, reference and consistency checks | [Build](./build.md), [Versioning](./versioning.md) |
| `Vcs.GitHub` | default | | Reads the GitHub Actions variables: CI detection, run number, tag, pull request, repository URL | [Versioning](./versioning.md#ci-variables) |
| `TfmConstants` | default | | `IsNET8`, `IsNET8_OR_GREATER`, `IsNETSTANDARD` and the rest, for conditions | [Build](./build.md#target-framework-constants) |
| `Packaging` | default | | nuget.org metadata defaults, the readme generator and the `MSKITPKG` checks | [Packaging](./packaging.md) |
| `Testing` | default | | Test-project detection, Microsoft.Testing.Platform, assertions, mocking, `InternalsVisibleTo` | [Testing](./testing.md) |
| `Testing.XUnit.v3` | default | `Testing` | The xUnit v3 wiring | [Testing](./testing.md) |
| `Locals.Secrets`, `Locals.DirectorySecrets`, `Locals.Compile` | default | | Secrets and source files that stay on the developer's machine | [Local files](./local-files.md) |
| `PrivateAssets` | default | | Keeps a project's references from flowing to its dependents | [Build](./build.md#private-references) |
| `Project.RoslynComponent` | optional | | The shared base of the three below | [Roslyn](./roslyn.md) |
| `Project.CodeAnalyzer` | optional | `Project.RoslynComponent` | Analyzer projects | [Roslyn](./roslyn.md) |
| `Project.CodeFixer` | optional | `Project.RoslynComponent`, `Project.CodeAnalyzer` | Code-fix projects, packed into the analyzer's package | [Roslyn](./roslyn.md) |
| `Project.SourceGenerator` | optional | `Project.RoslynComponent` | Source-generator projects | [Roslyn](./roslyn.md) |
| `PackageAsProj` | optional | | Swap a `PackageReference` for a `ProjectReference` to debug a dependency from source | [Optional parts](./optional-parts.md#packageasproj) |
| `ProjMetadata` | optional | | Writes each project's packages and assemblies to YAML | [Optional parts](./optional-parts.md#projmetadata) |
| `EF` | optional | | Entity Framework migration scripts | [Optional parts](./optional-parts.md#ef) |

## Load order

`Directory.Build.props` imports `.toolkit/msbuild/init.props`, which imports each installed part's `init.props` in a fixed order; `Directory.Build.targets` imports `init.targets` the same way. A part that is not installed is skipped.

| Phase | Order |
| --- | --- |
| props | `MSKit_BeforeInitProps` → owner layer (`init.company.props`) → Core → Vcs.GitHub → Locals.Compile → Locals.DirectorySecrets → Locals.Secrets → Project.RoslynComponent → Project.CodeFixer → Project.CodeAnalyzer → Project.SourceGenerator → TfmConstants → Trunk → Packaging → Testing → Testing.XUnit.v3 → EF → Trunk `init.last.props` (version engine) → `MSKit_AfterInitProps` |
| targets | `MSKit_BeforeInitTargets` → TfmConstants → owner layer (`init.company.targets`) → Core → Locals.* → Project.CodeAnalyzer → Project.SourceGenerator → Trunk → Packaging → Testing → Testing.XUnit.v3 → the `init.last.targets` of Trunk, Project.RoslynComponent, Testing.XUnit.v3, Testing, Project.CodeAnalyzer, PrivateAssets, PackageAsProj, ProjMetadata → every part's `audit/*.targets` → `MSKit_AfterInitTargets` |

In the props phase a default is written as `<X Condition="'$(X)'==''">`, so the **first** writer wins: a value you set in `Directory.Build.props` above the kit import beats the owner layer, which beats the parts. The exceptions are the owner layer's `ManufacturerName`, `FullManufacturerName` and `NoWarn`, which it sets unconditionally ([Customizing](./customizing.md#the-owner-layer)). The csproj body runs after all props, so a value set there wins too, except for the few properties the kit reads in the props phase (the test-project switches, `TargetFramework` detection); those pages say so. How to hook in your own files: [Customizing](./customizing.md).

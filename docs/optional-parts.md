# Optional parts

Three parts that are not installed by default. Add one with `sh .toolkit/update.sh --add <Part>` ([Install and update](./install-and-update.md)); the Roslyn parts have [their own page](./roslyn.md).

## PackageAsProj

Debug a dependency from its source: swap its `PackageReference` for a `ProjectReference` without editing every project. Point the package at a project file and switch it on:

```xml
<!-- Directory.PackageAsProj.targets, next to the solution -->
<Project>
  <ItemGroup>
    <PackageReference Update="Acme.Shared" ProjPath="../Shared/src/Acme.Shared/Acme.Shared.csproj" AsProj="true" />
  </ItemGroup>
</Project>
```

The kit imports `Directory.PackageAsProj.targets` from the solution folder when it exists, so the switch reaches every project; the same `Update` item works in a single csproj. Run `dotnet restore --force` after switching either way. `AsProj="false"` keeps the package and checks it is restored again.

| Code | When |
| --- | --- |
| [`MSKIT_PAP001`](./reference/codes.md#mskitpap001) | a package switched to a project is still resolved from the package: restore with `--force` |
| [`MSKIT_PAP002`](./reference/codes.md#mskitpap002) | a package switched back is not restored yet: restore with `--force`, or set `PackageAsProj_SkipChecks=True` |

Keep `Directory.PackageAsProj.targets` out of git if the paths point at your own checkouts.

## ProjMetadata

Lists each project's packages and resolved assemblies, per target framework, as YAML — for dependency reports and audits:

```sh
dotnet build MyRepo.slnx -p:ProjMetadataOutDir=artifacts/metadata
```

Each build of a project writes `<ProjMetadataOutDir>/<Project>.<TargetFramework>.metadata.yml` once its references are resolved:

```yaml
project: Acme.Masking
description: Masks sensitive values in JSON.
tfm: net8.0
useCPM: true
isPackage: True
packages:
  Acme.Shared: 1.2.0
assemblies:
  Acme.Shared:
    PackageId: Acme.Shared
    AssemblyVersion: 1.2.0.0
    PackageVersion: 1.2.0
```

With central package management, `packages` lists every `PackageVersion` the build knows, not only the ones the project references. Without `ProjMetadataOutDir` nothing is written.

## EF

PowerShell scripts around [`dotnet ef`](https://learn.microsoft.com/ef/core/cli/dotnet) migrations. They read the context and its project from `ef-scripts-init.ps1` in the repository root:

```powershell
# ef-scripts-init.ps1
$dbContext = 'OrdersDbContext'
$dbContextProj = "$PSScriptRoot/src/Acme.Orders.Data/Acme.Orders.Data.csproj"
```

```sh
pwsh .toolkit/msbuild/DragoAnt.MSBuildKit.EF/scripts/add-migration.ps1 -migrationName AddShippingAddress
pwsh .toolkit/msbuild/DragoAnt.MSBuildKit.EF/scripts/apply-migrations.ps1
pwsh .toolkit/msbuild/DragoAnt.MSBuildKit.EF/scripts/remove-migration.ps1
```

| Script | Runs |
| --- | --- |
| `add-migration.ps1 -migrationName <Name>` | `dotnet ef migrations add`; a migration with an empty `Up` is deleted again |
| `apply-migrations.ps1` | `dotnet ef database update` |
| `remove-migration.ps1` | `dotnet ef migrations remove` |

Each script first builds the context project (`--no-restore`) and runs `dotnet tool update --global dotnet-ef`, which installs or updates the **global** `dotnet-ef` tool. `-initFile <path>` uses another init file (absolute, or relative to the scripts folder). `MSKit_EFScriptsDir` holds the scripts folder for your own MSBuild targets.

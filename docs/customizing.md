# Customizing

Three ways to change what the kit does without editing `.toolkit/msbuild/` (an update overwrites it): set a property, add one of the extension files the kit looks for, or hook your own file in around the kit. To use the kit for another owner, change the owner layer.

## Overriding a default

Almost every default is written as `<X Condition="'$(X)'==''">`, so the first value set wins ([load order](./parts.md#load-order)):

| Where you set it | Effect |
| --- | --- |
| `Directory.Build.props`, above the kit import | every project, before the kit's defaults — the place for repository-wide choices such as `MSKit_VersionStrategy` or `MSKit_TestsAssertions` |
| `Directory.Build.props`, below the kit import | every project, after the kit's props-phase defaults — for values the kit sets unconditionally |
| the csproj | one project; it runs after all props, so it wins except for what the kit decides in the props phase (test-project detection, Roslyn role detection, `TargetFramework` shape) |
| `-p:Name=Value` | one build; a global property beats everything |

## The owner layer

`.toolkit/msbuild/init.company.props` is loaded before every part and holds the owner's defaults; `init.company.targets` is its targets-phase twin (empty for DragoAnt).

| Setting | DragoAnt value | Note |
| --- | --- | --- |
| `ManufacturerName`, `FullManufacturerName` | `DragoAnt` | **unconditional**: set them below the kit import to change them; they feed `Authors`, `Company`, `Copyright` |
| `PackageLicenseExpression` | `MIT`, unless `PackageLicenseFile` is set | |
| `PackageIconPath` | `.toolkit/res/package.icon.png` | |
| `MSKit_DefaultPackageIconUrl` | not set | another owner sets it here to a hosted copy of its icon, so older clients show it too ([Packaging](./packaging.md#package-metadata)) |
| `MSKit_PrereleasePackagePrefix` | `DragoAnt.` | [prerelease check](./build.md#reference-checks) |
| `MSKit_IsStableBranchRegex` | `^(main\|release/.+)$` | |
| `MSKit_VersionStrategy` | `ReleaseTag` | [Versioning](./versioning.md) |
| `IsPackable` | `True` | test projects and code fixes opt out |
| `TreatWarningsAsErrors` | `True` | |
| `NoWarn` | adds `CS1591;xUnit1051` | missing XML docs on public members; `CancellationToken` overloads in tests. Remove `CS1591` below the kit import to gate on XML docs |
| `WarningsNotAsErrors` | adds `NU1901;NU1902;NU1903;NU1904` | a newly disclosed vulnerability stays a warning, so the fix can be scheduled |
| `MSKit_TestingFramework`, `MSKit_TestsAssertions` | `xunit.v3`, `AwesomeAssertions` | [Testing](./testing.md) |
| `MSKit_RestrictPackageReference` | `Moq` as an error | [reference checks](./build.md#reference-checks) |

**Another owner:** fork the kit, change `kit/.toolkit/msbuild/init.company.props` (and `.targets`) and `kit/.toolkit/res/package.icon.png`, publish releases from the fork and install with `update.sh --repo <owner>/<fork>` (recorded in `kit.json`, so later updates come from the fork). Set `MSKit_CodesHelpBaseUrl` in the owner layer to point the code links at the fork's code reference. No part names an owner.

## Extension files

The kit imports these from the solution folder (`MSKit_SlnFileDirectory`) when they exist:

| File | Phase | Use |
| --- | --- | --- |
| `Directory.Version.props` | props | `VersionPrefix` ([Versioning](./versioning.md)) |
| `Directory.GlobalUsings.props`, `Directory.GlobalUsings.targets` | props, targets | your own `<Using>` items |
| `Directory.Packages.Metadata.targets` | targets | `PackageReference Update` items with metadata such as `PrivateAssets` |
| `Directory.PackageAsProj.targets` | targets | the package-to-project switches ([PackageAsProj](./optional-parts.md#packageasproj)) |

## Hooks around the kit

Name your own files in `Directory.Build.props` above the kit import; each is imported only when it exists:

| Property | Imported |
| --- | --- |
| `MSKit_BeforeInitProps` | before the owner layer and every part's props |
| `MSKit_AfterInitProps` | after every part's props, the version engine included |
| `MSKit_BeforeInitTargets` | before every part's targets |
| `MSKit_AfterInitTargets` | after every part's targets and audits |

```xml
<PropertyGroup>
  <MSKit_AfterInitTargets>$(MSBuildThisFileDirectory)build/after-kit.targets</MSKit_AfterInitTargets>
</PropertyGroup>
<Import Project="$(MSBuildThisFileDirectory).toolkit/msbuild/init.props" />
```

`MSKit_BeforeInitTargets` and `MSKit_AfterInitTargets` are read in the targets phase, so they can also be set in the csproj.

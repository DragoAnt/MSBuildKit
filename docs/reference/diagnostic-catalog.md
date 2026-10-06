# Diagnostic catalog

Every code the kit reports is also declared as an MSBuild item, `BuildDiagnosticDescriptor`, so a tool that collects a build's warnings and errors can name, group and explain them without parsing this documentation. The [code reference](./codes.md) is the same catalog for readers.

## The item

```xml
<BuildDiagnosticDescriptor Include="MSKITVER007"
                           Title="Release tag differs from VersionPrefix"
                           MessageFormat="Release tag '{0}' has version core {1}, but the repository declares VersionPrefix {2}.%0AFix: ..."
                           Description="The tag's MAJOR.MINOR.PATCH differs from the VersionPrefix the repository declares."
                           Category="Versioning"
                           DefaultSeverity="Warning"
                           HelpLink="$(MSKit_CodesHelpBaseUrl)#mskitver007" />
```

| Metadata | Value |
| --- | --- |
| `Include` | The code |
| `Title` | The code's short name: the bold line that opens its section of the code reference |
| `MessageFormat` | The text the build reports, with `{0}`, `{1}`, … where it inserts a value such as a project name, a path or a list; a value used twice keeps its number, and `%0A` is a line break |
| `Description` | The opening sentence or two of the code's section, as plain text |
| `Category` | The family the code's section is under: `Packaging`, `Versioning`, `References`, `Shared properties`, `Project types`, `Testing` or `PackageAsProj` |
| `DefaultSeverity` | `Warning` or `Error`: how the code is reported on a developer machine with the kit's defaults. The section says what changes it; the `MSKITPKG001`-`MSKITPKG019` checks, for one, become errors on CI |
| `HelpLink` | The code's section, the same link the warning or error carries; it follows `MSKit_CodesHelpBaseUrl` |

`Category` is the family rather than the letters of the code because a family is what a reader groups by, and two of them hold more than one prefix (`References` has `DUP`, `PRE` and `RES`); the prefix is already in the code.

## Where the items live

Each part declares the codes it reports in its own folder, `.toolkit/msbuild/DragoAnt.MSBuildKit.<Part>/diagnostic.descriptors.props`, which the part's `init.props` imports. A project therefore sees the descriptors of the parts it has installed and no others, and the `DefiningProjectFullPath` of an item names the part that owns the code; `.toolkit/kit.json` holds the kit version. The [code reference](./codes.md) lists which part reports which family.

```sh
dotnet msbuild src/MyLibrary/MyLibrary.csproj -getItem:BuildDiagnosticDescriptor
```

prints the catalog of one project as JSON. It lists every code the installed parts can report; which of them a build did report is in that build's own output.

A reserved code has no item: `VER003` was never reported and never will be.

## Adding your own

The item is not tied to the kit's codes or prefix, so your own checks can join the same catalog.

- **Checks in a repository or in a company's shared build files:** put the items in a props file that ships next to the targets that report the codes, and import it from your props (for instance through `MSKit_AfterInitProps`, [Customizing](../customizing.md#hooks-around-the-kit)). Keep one file per set of checks that is versioned together, never one central file for all of them: a collector attributes a code to the file that defines its item.
- **A part added to a fork of the kit:** add `diagnostic.descriptors.props` to the part's folder and import it from the part's `init.props` ([CONTRIBUTING](../../CONTRIBUTING.md#changing-the-kit)).

## How the catalog stays true

The items and the code reference are both written by hand, and `sh tools/docs-check.sh`, which CI runs, fails when they drift. The reference cannot be generated from the items, because its sections carry what a descriptor has no place for: the fix, the switches, the links. Generating the items from the reference would mean parsing prose into XML and committing the output beside its source, which is two copies again with a generator to maintain. So the check compares them instead: every reported code has exactly one item, in the part that reports it; `Title`, `Category`, `DefaultSeverity` and `Description` equal the title line, family, `(warning)` / `(error)` mark and opening sentences of the code's section; `MessageFormat` equals the text of the `<Warning>` or `<Error>` that reports the code, expressions replaced by placeholders; `HelpLink` equals the task's.

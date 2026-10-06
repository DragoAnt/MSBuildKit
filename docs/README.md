# MSBuildKit documentation

Read in this order; each page stands on its own, so jump to the one you need.

| # | Page | Read it to |
| --- | --- | --- |
| 1 | [Getting started](./getting-started.md) | install the kit, build, test and pack a first library |
| 2 | [Install and update](./install-and-update.md) | move to another version, add or remove parts, install a local build |
| 3 | [Parts](./parts.md) | see what each part does, which are installed by default and the order they load in |
| 4 | [Build defaults and checks](./build.md) | know the language defaults, the owner layer, CI detection, target-framework rules and reference audits |
| 5 | [Versioning](./versioning.md) | control how package versions are computed |
| 6 | [Local files and secrets](./local-files.md) | keep secrets and machine-only source files out of the repository |
| 7 | [Optional parts](./optional-parts.md) | debug a dependency from source, list a project's packages, run Entity Framework migrations |
| 8 | [Packaging](./packaging.md) | understand the nuget.org defaults and the `MSKITPKG` checks |
| 9 | [Package readme](./package-readme.md) | generate every package's readme from the repository README |
| 10 | [Testing](./testing.md) | set up test projects, assertions, mocking and coverage |
| 11 | [Roslyn components](./roslyn.md) | build analyzers, code fixes and source generators |
| 12 | [Customizing](./customizing.md) | change the owner, import your own files, override a default |
| 13 | [Troubleshooting](./troubleshooting.md) | fix a failing build or update |
| 14 | [Code reference](./reference/codes.md) | look up any warning or error the kit reports |
| 15 | [Property reference](./reference/properties.md) | look up any property the kit sets or reads |
| 16 | [Diagnostic catalog](./reference/diagnostic-catalog.md) | read the kit's codes from a tool, or add your own to the catalog |
| 17 | [Migrating from MSBuild.Routine](./migrating-from-msbuild-routine.md) | move a repository off the older submodule |

Contributing to the kit itself: [CONTRIBUTING.md](../CONTRIBUTING.md).

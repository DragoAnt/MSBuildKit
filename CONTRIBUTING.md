# Contributing

Issues and pull requests are welcome.

## Layout

- `kit/.toolkit/` is exactly what a release zip contains and what `update.sh` / `update.ps1` install: `msbuild/` (one folder per part plus the `init.props` / `init.targets` entry points), `res/`, `kit.parts` and the update scripts.
- `samples/MinimalLibrary` is a consumer with a library and a test project; its `.toolkit/` is installed by the self-test and not committed.
- `tests/run.sh` is the self-test; `tests/fixtures/PackageChecks` breaks every package rule on purpose. `tests/manager.sh` builds, tests, packs and installs the tool.
- `tools/pack-kit.sh` builds the release zip and its SHA-256.
- `manager/` is the `mskit-manager` .NET tool: its own solution, central package versions and `global.json`, built against `manager/.toolkit/` — the working-tree kit installed with `sh kit/.toolkit/update.sh --source kit --root manager` and committed.
- `docs/` holds the user documentation, read in the order of [docs/README.md](./docs/README.md); `docs/reference/` lists every property and code. `tools/docs-check.sh` keeps them honest against the kit.

## Build and test

You need the .NET 10 SDK and the .NET 8 runtime, plus `sh` (Git Bash on Windows).

```sh
sh tests/run.sh
```

It installs the working-tree kit into the sample and the fixtures with `update.sh`, then checks the computed versions for local, branch, pull-request and tag builds, runs the sample's tests with coverage, inspects the packed nuspec, asserts that every `MSKITPKG` check fires on the fixtures, and runs `sh tools/docs-check.sh`. CI runs the same script on Linux and Windows.

The tool has its own script:

```sh
sh tests/manager.sh
```

It builds and tests the tool from `manager/`, so its `global.json` selects Microsoft.Testing.Platform, then packs it, installs the packed tool into a tool path and runs `mskit-manager --help` and `status --json`. CI's `manager` job runs the same script. For the tests alone, `cd manager && dotnet test --solution DragoAnt.MSBuildKit.Manager.slnx`.

### NuGet packages during a run

Both scripts restore into a global-packages folder of their own, `dist/selftest-nuget-packages` and `dist/manager-nuget-packages`, and remove it when the run ends. A package built by a test therefore never reaches the machine's folder (`dotnet nuget locals global-packages --list`), where any other build on the machine would resolve it instead of the published one.

- The machine's folder stays a fallback folder (`NUGET_FALLBACK_PACKAGES`): a package it already holds is read from there, and NuGet writes nothing to a fallback folder. Everything else is downloaded into the run's folder; the HTTP cache is shared as usual.
- `--no-nuget-fallback` restores every package into the run's folder.
- Set `NUGET_PACKAGES` before the run to choose the folder yourself: the scripts then use it as it is and leave it in place.
- Each run ends by packing a probe package, restoring it, and failing if a package the run built is in the machine's folder.

## Changing the kit

- A new property defaults with `Condition="'$(Name)'==''"`, so a consumer's value always wins, and gets a row in [docs/reference/properties.md](./docs/reference/properties.md) plus a mention on its topic page.
- A new check gets an `MSKIT<AREA><nnn>` code with no separator (a shipped code is never renumbered or reused), a `HelpLink="$(MSKit_CodesHelpBaseUrl)#<code, lower case>"`, a message that says how to fix it, a section in [docs/reference/codes.md](./docs/reference/codes.md) headed by the code, a `BuildDiagnosticDescriptor` item in its part's `diagnostic.descriptors.props` ([diagnostic catalog](./docs/reference/diagnostic-catalog.md)), a fixture that triggers it and a line in `tests/run.sh`.
- `sh tools/docs-check.sh` fails on a property, item or code without its reference entry, on a name the docs mention that the kit lacks, and on a broken relative link; `--list properties|items|codes` prints the kit's inventory with the file and line of each.
- The README stays short: key features, install, links. Detail goes to the topic page in `docs/`.
- A new part needs a line in `kit/.toolkit/kit.parts` and its `init.props` / `init.targets` imports in the entry points.
- Keep scripts POSIX `sh` and PowerShell 7 equivalent; `update.sh` and `update.ps1` must produce the same `.toolkit/`.
- A test that restores a package built in this repository runs from `tests/run.sh` or `tests/manager.sh`, which keep it out of the machine's global-packages folder.
- Add a line to `CHANGELOG.md` under `Unreleased`.

## Releasing

Publish a GitHub release with a SemVer tag such as `v0.2.0`. The release workflow runs the self-test and uploads `msbuildkit-<version>.zip`, its `.sha256` and the update scripts to the release.

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

Both scripts restore into folders of their own and share third-party packages between runs. A run never restores from or writes to the machine's global-packages folder (`dotnet nuget locals global-packages --list`), so a package built by a test cannot reach it, where any other build on the machine would resolve it instead of the published one.

| Folder | What | Lifetime |
| --- | --- | --- |
| `dist/nuget-runs/<script>.<pid>.<time>/packages` | the run's global-packages folder (`NUGET_PACKAGES`) | removed when the run ends, also on Ctrl+C or a termination signal |
| `dist/nuget-runs/<script>.<pid>.<time>/http-cache` | the run's HTTP cache (`NUGET_HTTP_CACHE_PATH`) | the same |
| `dist/nuget-shared` | the shared fallback folder (`NUGET_FALLBACK_PACKAGES`): third-party packages earlier runs downloaded | kept; delete it to start cold |

- **Harvest.** When a run ends, each package it downloaded from an `https` feed moves into the shared folder, staged first and published with one rename, so parallel runs and a killed run cannot leave a half-written package. A package from a local folder, a loopback feed or plain `http` never moves there, and neither does a **kit package**: an id that starts with one of `DragoAnt.MSBuildKit`, `DragoAnt.Fixture.`, `DragoAnt.Samples.`. So a restore never gets a shared copy in place of a fresh local build.
- **Variables.** `MSBUILDKIT_TESTS_NUGET_SHARED_DIR` names another shared folder, for example one that several checkouts use; the scripts refuse the machine's global-packages folder there, also behind a link or another spelling, and refuse a folder that already holds a kit package. `MSBUILDKIT_TESTS_KIT_PACKAGE_PREFIXES` replaces the kit prefixes (`;`-separated); a prefix matches the id itself and every id that continues it after a dot, in any case.
- **Clearing.** `rm -rf dist/nuget-shared` (or your own folder); the next run downloads again. A run killed outright leaves its `dist/nuget-runs` folder behind, and the next run removes it: only folders that carry the run marker file and whose process is gone.
- `--no-nuget-fallback` neither reads nor fills the shared folder. A caller's `NUGET_PACKAGES`, `NUGET_HTTP_CACHE_PATH` or `NUGET_FALLBACK_PACKAGES` is used as it is; with your own `NUGET_PACKAGES` nothing is harvested.
- **Guard.** The check only reads the machine's folder: each run lists the kit packages there with their hashes when it starts, and fails at its end if that list changed (added, changed or removed) or the folder holds a package the run built. It cannot see a third-party package that was changed or deleted there, nor a package packed outside the run's output directory whose id has no kit prefix.
- A package that cannot be moved into the shared folder, and a run folder that cannot be removed, are reported in a `NOTE` line and do not fail the run; the next run removes the folder. The scripts stop no process and clear no machine-wide cache. `tests/nuget-isolation.test.sh` checks the rules on hand-made folders, with a stand-in for the machine's folder.
- A test reads restored packages through `ni_packages_dir`; a test file that names a packages folder itself fails the run. A scenario that needs a folder of its own sets `NUGET_PACKAGES` for that command: the variable outranks `globalPackagesFolder` in a `nuget.config`.
- Do not wrap the scripts in `timeout`: it ends a child `dotnet` process in the middle of a restore.

## Changing the kit

- A new property defaults with `Condition="'$(Name)'==''"`, so a consumer's value always wins, and gets a row in [docs/reference/properties.md](./docs/reference/properties.md) plus a mention on its topic page.
- A new check gets an `MSKIT<AREA><nnn>` code with no separator (a shipped code is never renumbered or reused), a `HelpLink="$(MSKit_CodesHelpBaseUrl)#<code, lower case>"`, a message that says how to fix it, a section in [docs/reference/codes.md](./docs/reference/codes.md) headed by the code, a `BuildDiagnosticDescriptor` item in its part's `diagnostic.descriptors.props` ([diagnostic catalog](./docs/reference/diagnostic-catalog.md)), a fixture that triggers it and a line in `tests/run.sh`.
- `sh tools/docs-check.sh` fails on a property, item or code without its reference entry, on a name the docs mention that the kit lacks, and on a broken relative link; `--list properties|items|codes` prints the kit's inventory with the file and line of each.
- The README stays short: key features, install, links. Detail goes to the topic page in `docs/`.
- A new part needs a line in `kit/.toolkit/kit.parts` and its `init.props` / `init.targets` imports in the entry points.
- Keep scripts POSIX `sh` and PowerShell 7 equivalent; `update.sh` and `update.ps1` must produce the same `.toolkit/`.
- A test that restores a package built in this repository runs from `tests/run.sh` or `tests/manager.sh`, which keep it out of the machine's global-packages folder and out of the shared folder.
- Add a line to `CHANGELOG.md` under `Unreleased`.

## Releasing

Publish a GitHub release with a SemVer tag such as `v0.2.0`. The release workflow runs the self-test and uploads `msbuildkit-<version>.zip`, its `.sha256` and the update scripts to the release.

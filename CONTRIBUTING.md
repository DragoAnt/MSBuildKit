# Contributing

Issues and pull requests are welcome.

## Layout

- `kit/.toolkit/` is exactly what a release zip contains and what `update.sh` / `update.ps1` install: `msbuild/` (one folder per part plus the `init.props` / `init.targets` entry points), `res/`, `kit.parts` and the update scripts.
- `samples/MinimalLibrary` is a consumer with a library and a test project; its `.toolkit/` is installed by the self-test and not committed.
- `tests/run.sh` is the self-test; `tests/fixtures/PackageChecks` breaks every package rule on purpose.
- `tools/pack-kit.sh` builds the release zip and its SHA-256.
- `docs/` holds the user documentation, read in the order of [docs/README.md](./docs/README.md); `docs/reference/` lists every property and code. `tools/docs-check.sh` keeps them honest against the kit.

## Build and test

You need the .NET 10 SDK and the .NET 8 runtime, plus `sh` (Git Bash on Windows).

```sh
sh tests/run.sh
```

It installs the working-tree kit into the sample and the fixtures with `update.sh`, then checks the computed versions for local, branch, pull-request and tag builds, runs the sample's tests with coverage, inspects the packed nuspec, asserts that every `MSKIT_PKG` check fires on the fixtures, and runs `sh tools/docs-check.sh`. CI runs the same script on Linux and Windows.

## Changing the kit

- A new property defaults with `Condition="'$(Name)'==''"`, so a consumer's value always wins, and gets a row in [docs/reference/properties.md](./docs/reference/properties.md) plus a mention on its topic page.
- A new check gets an `MSKIT_<AREA><nnn>` code (a shipped code is never renumbered or reused), a message that says how to fix it, a section in [docs/reference/codes.md](./docs/reference/codes.md) headed by the code id without the underscore, a fixture that triggers it and a line in `tests/run.sh`.
- `sh tools/docs-check.sh` fails on a property, item or code without its reference entry, on a name the docs mention that the kit lacks, and on a broken relative link; `--list properties|items|codes` prints the kit's inventory with the file and line of each.
- The README stays short: key features, install, links. Detail goes to the topic page in `docs/`.
- A new part needs a line in `kit/.toolkit/kit.parts` and its `init.props` / `init.targets` imports in the entry points.
- Keep scripts POSIX `sh` and PowerShell 7 equivalent; `update.sh` and `update.ps1` must produce the same `.toolkit/`.
- Add a line to `CHANGELOG.md` under `Unreleased`.

## Releasing

Publish a GitHub release with a SemVer tag such as `v0.2.0`. The release workflow runs the self-test and uploads `msbuildkit-<version>.zip`, its `.sha256` and the update scripts to the release.

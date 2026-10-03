# Contributing

Issues and pull requests are welcome.

## Layout

- `kit/.toolkit/` is exactly what a release zip contains and what `update.sh` / `update.ps1` install: `msbuild/` (one folder per part plus the `init.props` / `init.targets` entry points), `res/`, `kit.parts` and the update scripts.
- `samples/MinimalLibrary` is a consumer with a library and a test project; its `.toolkit/` is installed by the self-test and not committed.
- `tests/run.sh` is the self-test; `tests/fixtures/PackageChecks` breaks every package rule on purpose.
- `tools/pack-kit.sh` builds the release zip and its SHA-256.

## Build and test

You need the .NET 10 SDK and the .NET 8 runtime, plus `sh` (Git Bash on Windows).

```sh
sh tests/run.sh
```

It installs the working-tree kit into the sample and the fixtures with `update.sh`, then checks the computed versions for local, branch, pull-request and tag builds, runs the sample's tests with coverage, inspects the packed nuspec, and asserts that every `MSKIT_PKG` check fires on the fixtures. CI runs the same script on Linux and Windows.

## Changing the kit

- A new property defaults with `Condition="'$(Name)'==''"`, so a consumer's value always wins, and gets a row in the README.
- A new check gets an `MSKIT_<AREA><nnn>` code, a message that says how to fix it, a fixture that triggers it and a line in `tests/run.sh`.
- A new part needs a line in `kit/.toolkit/kit.parts` and its `init.props` / `init.targets` imports in the entry points.
- Keep scripts POSIX `sh` and PowerShell 7 equivalent; `update.sh` and `update.ps1` must produce the same `.toolkit/`.
- Add a line to `CHANGELOG.md` under `Unreleased`.

## Releasing

Publish a GitHub release with a SemVer tag such as `v0.2.0`. The release workflow runs the self-test and uploads `msbuildkit-<version>.zip`, its `.sha256` and the update scripts to the release.

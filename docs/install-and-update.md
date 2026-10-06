# Install and update

The kit is installed and updated by one script, `update.sh` (POSIX `sh`) or its twin `update.ps1` ([PowerShell 7](https://learn.microsoft.com/powershell/scripting/install/installing-powershell)); both produce the same `.toolkit/`. A copy of each lives in `.toolkit/` after the first install.

```sh
sh .toolkit/update.sh                         # reinstall the version pinned in .toolkit/kit.json
sh .toolkit/update.sh --version 0.2.1         # move to another version
sh .toolkit/update.sh --add EF --dry-run      # preview adding an optional part
sh .toolkit/update.sh --remove EF             # uninstall it again
```

## Options

| `update.sh` | `update.ps1` | Meaning |
| --- | --- | --- |
| `--version X.Y.Z` | `-Version` | The kit version to install; a leading `v` is ignored. Default: the version in `.toolkit/kit.json`, else the latest release |
| `--add PART` | `-Add` | Install an optional part; repeat for several. Parts it requires come with it |
| `--remove PART` | `-Remove` | Uninstall an optional part; a default part cannot be removed |
| `--dry-run` | `-DryRun` | List the files under `.toolkit/msbuild/` that would be added, removed or changed, and change nothing |
| `--source DIR\|ZIP` | `-Source` | Install a local build of the kit: a folder holding `.toolkit/msbuild/init.props`, or a release zip |
| `--sha256 HEX` | `-Sha256` | The SHA-256 the release zip (or a `--source` zip) must have |
| `--repo OWNER/NAME` | `-Repo` | The GitHub repository to download from. Default: the one in `kit.json`, else `DragoAnt/MSBuildKit` |
| `--root DIR` | `-Root` | The repository root. Default: the current folder |

**Moving to the newest release:** once `kit.json` exists, a run without `--version` reinstalls the pinned version. Pass the version you want; the [releases page](https://github.com/DragoAnt/MSBuildKit/releases) lists them, with what changed.

## What a run checks and writes

1. It downloads `msbuildkit-<version>.zip` and its `.sha256` from the release, and stops unless the zip matches the published hash. When the version is the one already pinned, the zip must also match the `sha256` in `kit.json`, so a release replaced after you installed it is refused.
2. It selects the parts: every default part, the optional parts recorded in `kit.json`, plus `--add`, minus `--remove`, plus everything those require ([Parts](./parts.md)).
3. It replaces `.toolkit/msbuild/` with the selected parts, copies `.toolkit/res/`, `.toolkit/kit.parts` and the two update scripts, and rewrites `kit.json`.
4. It creates `Directory.Build.props` and `Directory.Build.targets` when they are missing; when they exist without the kit import, it prints the line to add.

`.toolkit/.local/` and every other file of yours are left alone. `--dry-run` reports step 3 for `.toolkit/msbuild/` only and writes nothing.

## `kit.json`

```json
{
  "repository": "DragoAnt/MSBuildKit",
  "version": "0.2.1",
  "sha256": "<sha-256 of msbuildkit-0.2.1.zip>",
  "parts": ["PackageAsProj", "EF"]
}
```

Commit it with `.toolkit/`. `parts` lists only the optional parts you chose; default parts are always installed. A `--source` install records the local build's version (or `0.0.0-local`) and the zip's hash, empty for a folder.

## Installing a local build

To try a change to the kit in a consumer repository before it is released:

```sh
sh <kit-checkout>/kit/.toolkit/update.sh --source <kit-checkout>/kit --root <consumer>
```

`tools/pack-kit.sh <version>` in the kit repository builds the same zip a release publishes ([CONTRIBUTING.md](../CONTRIBUTING.md)).

## Updating from 0.2.0 or earlier

An update started from 0.2.0 or earlier still runs the old script, which can stop with a `syntax error` after copying the files and before writing `kit.json` when the new `update.sh` differs in length (a CRLF checkout does). Run the same command once more; updates started from 0.2.1 on finish in one run.

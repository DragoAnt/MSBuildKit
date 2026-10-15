# Install and update

The kit is installed and updated by one script, `update.sh` (POSIX `sh`) or its twin `update.ps1` ([PowerShell 7](https://learn.microsoft.com/powershell/scripting/install/installing-powershell)); both produce the same kit folder, `.mskit/` unless you choose another name. A copy of each lives in the kit folder after the first install.

```sh
sh .mskit/update.sh                         # reinstall the version pinned in .mskit/kit.json
sh .mskit/update.sh --version 0.2.1         # move to another version
sh .mskit/update.sh --add EF --dry-run      # preview adding an optional part
sh .mskit/update.sh --remove EF             # uninstall it again
```

## Options

| `update.sh` | `update.ps1` | Meaning |
| --- | --- | --- |
| `--version X.Y.Z` | `-Version` | The kit version to install; a leading `v` is ignored. Default: the version in `.mskit/kit.json`, else the latest release |
| `--add PART` | `-Add` | Install an optional part; repeat for several. Parts it requires come with it |
| `--remove PART` | `-Remove` | Uninstall an optional part; a default part cannot be removed |
| `--dry-run` | `-DryRun` | List the files under `.mskit/msbuild/` that would be added, removed or changed, and the folder move and rewrites of a [migration](#moving-from-toolkit), and change nothing |
| `--kit-dir NAME` | `-KitDir` | The kit folder, a folder name in the repository root. Default: the folder whose `kit.json` records its own name as `kitDir`, else `.mskit`. Two folders claiming the kit stop the run |
| `--source DIR\|ZIP` | `-Source` | Install a local build of the kit: a folder holding `.toolkit/msbuild/init.props` (the release zip's layout), or a release zip |
| `--sha256 HEX` | `-Sha256` | The SHA-256 the release zip (or a `--source` zip) must have |
| `--repo OWNER/NAME` | `-Repo` | The GitHub repository to download from. Default: the one in `kit.json`, else `DragoAnt/MSBuildKit` |
| `--root DIR` | `-Root` | The repository root. Default: the current folder |

**Moving to the newest release:** once `kit.json` exists, a run without `--version` reinstalls the pinned version. Pass the version you want; the [releases page](https://github.com/DragoAnt/MSBuildKit/releases) lists them, with what changed.

## What a run checks and writes

1. It downloads `msbuildkit-<version>.zip` and its `.sha256` from the release, and stops unless the zip matches the published hash. When the version is the one already pinned, the zip must also match the `sha256` in `kit.json`, so a release replaced after you installed it is refused.
2. It selects the parts: every default part, the optional parts recorded in `kit.json`, plus `--add`, minus `--remove`, plus everything those require ([Parts](./parts.md)).
3. When the repository still has an older `.toolkit/` install, it [moves it](#moving-from-toolkit) to the kit folder first.
4. It replaces `.mskit/msbuild/` with the selected parts, copies `.mskit/res/`, `.mskit/kit.parts` and the two update scripts, and rewrites `kit.json`.
5. It creates `Directory.Build.props` and `Directory.Build.targets` when they are missing; when they exist without the kit import, it prints the line to add.

`.mskit/.local/` and every other file of yours are left alone. `--dry-run` reports steps 3 and 4 and writes nothing.

## `kit.json`

```json
{
  "repository": "DragoAnt/MSBuildKit",
  "version": "0.2.1",
  "sha256": "<sha-256 of msbuildkit-0.2.1.zip>",
  "parts": ["PackageAsProj", "EF"],
  "kitDir": ".mskit"
}
```

Commit it with `.mskit/`. `parts` lists only the optional parts you chose; default parts are always installed. `kitDir` is the folder's own name, which is how a later run without `--kit-dir` finds a folder you named yourself. A `--source` install records the local build's version (or `0.0.0-local`) and the zip's hash, empty for a folder.

## Installing a local build

To try a change to the kit in a consumer repository before it is released:

```sh
sh <kit-checkout>/kit/.toolkit/update.sh --source <kit-checkout>/kit --root <consumer>
```

`tools/pack-kit.sh <version>` in the kit repository builds the same zip a release publishes ([CONTRIBUTING.md](../CONTRIBUTING.md)).

## Moving from `.toolkit/`

Releases up to 0.2.1 installed the kit into `.toolkit/`. When a run finds `.toolkit/` holding a kit whose `kit.json` has no `kitDir`, and the kit folder does not exist yet, it:

1. moves `.toolkit/` to the kit folder, `.local/` templates included: with `git mv` when `.toolkit/` is tracked, so the rename is staged, else with a plain move;
2. rewrites `.toolkit` to the new name wherever it is a whole path segment in `Directory.Build.props`, `Directory.Build.targets`, `.gitignore` and `.github/dependabot.yml` (`/` and `\` spellings alike; a name such as `my.toolkit` is left alone);
3. names every move and rewrite in its output, then installs as usual.

When both `.toolkit/` and the kit folder exist, the run stops and changes nothing: remove the one you do not use. To keep the kit in `.toolkit/`, pass `--kit-dir .toolkit` once; `kit.json` remembers it. Preview the move with `--dry-run`.

**From 0.2.1 it takes two runs.** The installed 0.2.1 `update.sh` knows only `.toolkit/`: it installs the new version there and copies in the new `update.sh` without running it. Run the new script once more and it moves the kit:

```sh
sh .toolkit/update.sh --version <new version>   # 0.2.1's script: installs into .toolkit/, copies the new update.sh
sh .toolkit/update.sh                           # the new script: moves .toolkit/ to .mskit/
```

`update.ps1` works the same way. Commit after the second run.

**A run that stopped after the move** (interrupted, or 0.3.0's `update.sh` stopped by a timeout) leaves the kit in `.mskit/` while `Directory.Build.props` / `.targets` still import `.toolkit/msbuild/init.*`, so the repository does not build. Run the update once more from the kit folder: when `Directory.Build.*` import `.toolkit/msbuild/init.*` and `.toolkit/` is gone, it rewrites `.toolkit` in the same four files and finishes. A run stopped by a signal says so and exits non-zero. A repository left this way by 0.3.0 holds 0.3.0's script, which cannot repair it, so take the new script first:

```sh
sh .mskit/update.sh --version <new version>   # 0.3.0's script: installs the new version, copies the new update.sh
sh .mskit/update.sh                           # the new script: rewrites the imports
```

## Updating from 0.2.0 or earlier

An update started from 0.2.0 or earlier still runs the old script, which can stop with a `syntax error` after copying the files and before writing `kit.json` when the new `update.sh` differs in length (a CRLF checkout does). Run the same command once more; updates started from 0.2.1 on finish in one run.

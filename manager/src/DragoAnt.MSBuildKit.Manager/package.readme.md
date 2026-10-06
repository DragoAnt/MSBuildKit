# DragoAnt.MSBuildKit.Manager

`mskit-manager` is the .NET tool behind [DragoAnt.MSBuildKit](https://github.com/DragoAnt/MSBuildKit): it installs, updates and migrates the kit in a repository.

## Install

```sh
dotnet new tool-manifest
dotnet tool install DragoAnt.MSBuildKit.Manager
dotnet mskit-manager status --json
```

## Commands

| Command | Does |
| --- | --- |
| `status [--json]` | prints the tool version |

Global options: `--no-logo`, `--diagnostic`, `--log-to-console`, `--no-color`. The logo and progress go to stderr; stdout carries only results.

This is an early build: the install, update and migrate commands arrive in later releases.

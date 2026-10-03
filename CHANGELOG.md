# Changelog

All notable changes to this project are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [SemVer](https://semver.org/).

## [Unreleased]

## [0.1.1] - 2026-10-04

### Fixed

- Packages ship their XML documentation file again: the `GenerateDocumentationFile` default moved to the props phase, where the SDK still honours it, so a `CS1591` gate in a consuming repository fires too.

## [0.1.0] - 2026-10-03

### Added

- Kit parts: Core, Trunk (version engine, product defaults, reference audits), Vcs.GitHub, TfmConstants, Packaging, Testing and Testing.XUnit.v3, Locals (Secrets, DirectorySecrets, Compile), PrivateAssets, and the optional PackageAsProj, Project.RoslynComponent/CodeAnalyzer/CodeFixer/SourceGenerator, ProjMetadata and EF parts.
- `ReleaseTag` version strategy: release tags become the package version (a leading `v` is removed), branches `{prefix}-ci.{run}`, pull requests `{prefix}-pr.{n}.{run}`; an invalid tag fails with `MSKIT_VER006`.
- nuget.org packaging defaults and nineteen `MSKIT_PKG` checks, warnings locally and errors on CI.
- Microsoft.Testing.Platform v2 test projects with xUnit v3, Cobertura coverage, TRX and JUnit reports.
- `update.sh` and `update.ps1`: install or update `.toolkit/` from a SHA-256 checked release zip, with optional parts and a dry run.
- `samples/MinimalLibrary`, the `tests/run.sh` self-test, and the CI and release workflows, with every action pinned to a full commit SHA.

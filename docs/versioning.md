# Versioning

The Trunk part computes `Version` and `PackageVersion` from a template; the Vcs.GitHub part feeds it the CI facts. `VersionPrefix`, declared in `Directory.Version.props`, is the next version the repository will release.

## The default: release tags

With the owner layer's `MSKit_VersionStrategy=ReleaseTag`:

| Build | Version | Template |
| --- | --- | --- |
| Developer machine (no `GITHUB_RUN_ID`) | `9999.0.0` | always, whatever the strategy (except `Manual`) |
| Tag `v2.0.0`, `2.0.0`, `v2.1.0-beta.1` | `2.0.0`, `2.0.0`, `2.1.0-beta.1` | `MSKit_ReleaseVersionTemplate` = `{releaseTag}` |
| Pull request 15, run 7 | `1.4.0-pr.15.7` | `MSKit_PullRequestVersionTemplate` = `{prefix}-pr.{prNumber}.{buildNumber}` |
| A stable branch (`main`, `release/*`), run 7 | `1.4.0-ci.7` | `MSKit_StableVersionTemplate` = `{prefix}-ci.{buildNumber}` |
| Any other branch, run 7 | `1.4.0-ci.7` | `MSKit_VersionTemplate` = `{prefix}-ci.{buildNumber}` |

A **tag build** is any GitHub Actions run with `GITHUB_REF_TYPE=tag`: publishing a GitHub release creates one, and so does pushing a tag without a release. A leading `v` or `V` is removed; the rest must be [SemVer 2.0](https://semver.org/), or restore fails with [`MSKITVER006`](./reference/codes.md#mskitver006). When the tag's `MAJOR.MINOR.PATCH` differs from `VersionPrefix`, [`MSKITVER007`](./reference/codes.md#mskitver007) reminds you to bump `VersionPrefix` after the release, so branch builds sort above it.

The template is picked in this order: a tag build with `MSKit_ReleaseVersionTemplate` set; a pull-request build with `MSKit_PullRequestVersionTemplate` set; a stable branch (`MSKit_IsStableBranch`, [Build](./build.md#roots-branch-and-commit)) → `MSKit_StableVersionTemplate`; anything else → `MSKit_VersionTemplate`. The version is rendered twice — in the props phase, so `dotnet msbuild -getProperty:Version` answers, and again before compile and pack, so a `VersionPrefix` or template set in a csproj is honoured.

## Other strategies

Set `MSKit_VersionStrategy` in `Directory.Build.props`. Any template can be overridden in `Directory.Build.props` or a csproj.

| Strategy | `VersionPrefix` default | `MSKit_VersionTemplate` | `MSKit_StableVersionTemplate` |
| --- | --- | --- | --- |
| `ReleaseTag` (owner layer) | `0.0.0` | `{prefix}-ci.{buildNumber}` | `{prefix}-ci.{buildNumber}` |
| `SemVer` (the kit's own default) | `1.0.0` | `{prefix}-{buildDateUtcDash}-{branchTicket}{branchAspectSuffix}` | `{prefix}` |
| `SemVer4` | `1.0.0` | `{prefix}.{buildNumber}-{buildDateUtcDash}-{branchTicket}{branchAspectSuffix}` | `{prefix}.{buildNumber}` |
| `DateBased` | the build date `yyyy.M.d` | `{buildDateUtcDot}.{buildNumber}-{branchTicket}{branchAspectSuffix}` | `{buildDateUtcDot}.{buildNumber}` |
| `VersionTag` | | `{versionTag}` | `{versionTag}` |
| `Manual` | | the engine is off: set `Version` yourself | |

Only `ReleaseTag` defines release-tag and pull-request templates; with the others a tag or pull-request build uses the branch templates unless you set them. `DateBased` uses the run id modulo 65535 as `{buildNumber}` (never 0). `VersionTag` needs `-p:VersionTag=1.2.3`, else [`MSKITVER004`](./reference/codes.md#mskitver004).

## Placeholders

| Placeholder | Value |
| --- | --- |
| `{prefix}` | `VersionPrefix` |
| `{buildNumber}` | `MSKit_BuildNumber`: the CI run number (`GITHUB_RUN_NUMBER`), `0` locally |
| `{pipelineId}` | `MSKit_CIPipelineId`: the CI run id (`GITHUB_RUN_ID`) |
| `{releaseTag}` | the tag without its leading `v` (tag builds only) |
| `{prNumber}` | the pull request number (pull-request builds only) |
| `{branchSlug}` | the branch with every character outside `[0-9A-Za-z-]` replaced by `-` |
| `{branchTicket}` | the first `[A-Za-z]+-[0-9]+` in `{branchSlug}` (`feat/ABC-12-x` → `ABC-12`), else `{branchSlug}` |
| `{branchAspectSuffix}` | the part of `{branchSlug}` from its first `--` on, else empty |
| `{buildDateUtcDash}` | the UTC build time as `yyyyMMdd-HHmmss` |
| `{buildDateUtcDot}` | the UTC build date as `yyyy.M.d` |
| `{versionTag}` | `VersionTag` |
| `{commitShaShort}` | the first 8 characters of `MSKit_CommitSha` |

An unknown placeholder fails the build with [`MSKITVER002`](./reference/codes.md#mskitver002). Each project reads the clock on its own; set `MSKit_BuildDateTimeUtc` (property or environment variable) once in CI so every project of one build gets the same date.

## Setting the version yourself

- **`-p:Version=2.0.0`**, or `Version` set in `Directory.Build.props` above the kit import, always wins: the engine renders nothing (`MSKit_ExplicitVersion`).
- **`<Version>` in a csproj** fails with [`MSKITVER001`](./reference/codes.md#mskitver001) while a template strategy is active, because it would be ignored: declare `VersionPrefix` in `Directory.Version.props`, or set `MSKit_VersionStrategy=Manual`.

## CI variables

The Vcs.GitHub part maps the [GitHub Actions variables](https://docs.github.com/actions/reference/variables-reference#default-environment-variables) onto the kit's properties. Each one except `MSKit_IsDevEnv`, `MSKit_IsGitHubCI` and `MSKit_VcsProvider` yields to a value you set, which is how another CI system can drive the engine: set `MSKit_IsDevEnv=False` and the properties below from its own variables.

| Property | From |
| --- | --- |
| `MSKit_IsDevEnv` | `False` when `GITHUB_RUN_ID` is set |
| `MSKit_IsGitHubCI` | `True` when `GITHUB_ACTIONS=true` or `GITHUB_RUN_ID` is set |
| `MSKit_CIPipelineId` | `GITHUB_RUN_ID` |
| `MSKit_BuildNumber` | `GITHUB_RUN_NUMBER` (the run id would overflow a version part) |
| `MSKit_CommitSha` | `GITHUB_SHA` |
| `MSKit_IsReleaseTag`, `MSKit_ReleaseTagRaw`, `MSKit_ReleaseTag` | `GITHUB_REF_TYPE=tag`, `GITHUB_REF_NAME`, and the latter without a leading `v` |
| `MSKit_PullRequestNumber` | from `GITHUB_REF` (`refs/pull/<n>/…`) on `pull_request` / `pull_request_target` events, or from a `GITHUB_REF_NAME` of `<n>/merge` |
| `RepositoryUrl` | `GITHUB_SERVER_URL/GITHUB_REPOSITORY` |
| `MSKit_VcsProvider` | `GitHub` |

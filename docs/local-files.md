# Local files and secrets

Three default parts keep values that must not be committed — connection strings, API keys, a developer's own settings — in the same per-user folder [`dotnet user-secrets`](https://learn.microsoft.com/aspnet/core/security/app-secrets) uses, and create them from templates that **are** committed. All three only act when a project (or the solution) opts in.

| Folder | Property |
| --- | --- |
| `%APPDATA%\Microsoft\UserSecrets\` (Windows), `~/.microsoft/usersecrets/` (Linux, macOS) | `MSKit_LocalSecretsBaseDirectory` |
| `<that folder>/<UserSecretsId>/` for a project | `LocalSecretsDir` |
| the templates: `.toolkit/.local/` | `MSKit_Templates` |

`update.sh` never touches `.toolkit/.local/`. Commit the templates with placeholders only — they reach every clone; the real values live only in the per-user folder.

## Locals.Secrets — a project's `secrets.json`

A project with a [`UserSecretsId`](https://learn.microsoft.com/aspnet/core/security/app-secrets#enable-secret-storage) gets, on a developer machine:

1. the template `.toolkit/.local/<UserSecretsId>.secrets.json`, created as `{}` when missing;
2. `secrets.json` in its `LocalSecretsDir`, copied from the template when missing (your edits there are kept);
3. that file linked into the project as `appsettings.UserSecrets.json` (`UserSecretsLinkNamePrefix` changes the `appsettings` part), so it is one click away in the IDE.

| Property | Default | Effect |
| --- | --- | --- |
| `MSKit_CopyUserSecretsIdToOutput` | empty | `true` copies the file to the build output |
| `MSKit_CopyUserSecretsIdToPublish` | empty | `true` copies it to the publish output |
| `MSKit_CopySecretsToProject`, `CopySecretsToProjectFileName` | `false`, empty | copy the file into the project folder under that name — and **replace the project's `.gitignore`** with that one name |
| `MSKit_SecretsCleanUp` | `True` on CI | delete `secrets.json` before restore and build |

## Locals.DirectorySecrets — solution-wide MSBuild secrets

For values MSBuild itself needs (a private feed's key, a signing password), turn on a solution-level props or targets file in `Directory.Build.props`:

```xml
<PropertyGroup>
  <MSKit_UseSlnSecretsProps>True</MSKit_UseSlnSecretsProps>
</PropertyGroup>
```

On a developer machine every project then imports `<user-secrets folder>/<MSKit_SlnSecretsId>/Directory.Secrets.props` (`MSKit_UseSlnSecretsTargets` does the same for `Directory.Secrets.targets`, in the targets phase), created from `.toolkit/.local/Directory.Secrets.props` when missing; the template is created as an empty `<Project>` when it is missing too. A file created during a build is imported from the next one on.

| Property | Default | Effect |
| --- | --- | --- |
| `MSKit_SlnSecretsId` | `MSKit_SlnFileName` | The folder name under the user-secrets folder. It is empty when a project is built on its own rather than through its `.slnx`: set it in `Directory.Build.props` for such builds |
| `MSKit_UseSlnSecretsProps`, `MSKit_UseSlnSecretsTargets` | `False` | Turn the two files on |
| `MSKit_SlnSecretsCleanUp` | `True` on CI | Delete the two files before restore and build |

## Locals.Compile — source files that stay local

A `LocalCompile` item compiles a file that lives in the project's `LocalSecretsDir`, for code that differs per developer (a fake credential provider, a debug switch):

```xml
<ItemGroup>
  <LocalCompile Include="LocalSettings.cs" />
</ItemGroup>
```

The project needs a `UserSecretsId`. The file is copied from the template `.toolkit/.local/LocalCompile/LocalSettings.cs` when it is missing; when the template is missing too, the kit writes a stub (`namespace <RootNamespace>;`) to it. This runs on every build, CI included, so the template must compile on its own. `LocalCompileTemplateDir` moves the template folder.

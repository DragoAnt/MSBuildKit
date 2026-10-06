namespace DragoAnt.MSBuildKit.Manager.Install;

/// <summary>Every path of an installed kit. The only place that knows the folder and file names.</summary>
internal sealed class KitLayout
{
    public const string DefaultKitDirName = ".mskit";
    public const string MsbuildDirName = "msbuild";
    public const string LocalDirName = ".local";
    public const string ManagerDirName = ".manager";
    public const string KitJsonFileName = "kit.json";
    public const string InitPropsFileName = "init.props";
    public const string InitTargetsFileName = "init.targets";
    public const string PackagesProjectFileName = "packages.csproj";
    public const string LockFileName = "packages.lock.json";
    public const string ManifestFileName = "manifest.json";

    /// <param name="root">The solution root, the folder holding <c>Directory.Build.props</c>.</param>
    /// <param name="kitDirName">The kit folder relative to <paramref name="root"/>; no <c>..</c> segment.</param>
    public KitLayout(string root, string kitDirName = DefaultKitDirName)
    {
        RequireRelativeKitDir(kitDirName);
        Root = root;
        KitDirName = kitDirName;
        KitPath = Path.Combine(root, kitDirName);
    }

    public string Root { get; }
    public string KitDirName { get; }
    public string KitPath { get; }
    public string KitJsonPath => Path.Combine(KitPath, KitJsonFileName);
    public string MsbuildPath => Path.Combine(KitPath, MsbuildDirName);
    public string InitPropsPath => Path.Combine(MsbuildPath, InitPropsFileName);
    public string InitTargetsPath => Path.Combine(MsbuildPath, InitTargetsFileName);
    public string LocalPath => Path.Combine(KitPath, LocalDirName);
    public string ManagerPath => Path.Combine(KitPath, ManagerDirName);
    public string PackagesProjectPath => Path.Combine(ManagerPath, PackagesProjectFileName);
    public string LockFilePath => Path.Combine(ManagerPath, LockFileName);
    public string ManifestPath => Path.Combine(ManagerPath, ManifestFileName);

    /// <summary>The folder a package's <c>msbuild/**</c> content is deployed to: <c>msbuild/&lt;package id&gt;</c>.</summary>
    public string PackageContentPath(string packageId)
    {
        if (string.IsNullOrWhiteSpace(packageId) || packageId is "." or ".." || packageId.IndexOfAny(['/', '\\']) >= 0)
            throw new ArgumentException($"'{packageId}' is not a package id", nameof(packageId));
        return Path.Combine(MsbuildPath, packageId);
    }

    private static void RequireRelativeKitDir(string kitDirName)
    {
        var segments = kitDirName.Split('/', '\\');
        var rooted = Path.IsPathRooted(kitDirName)
                     || kitDirName.StartsWith('/') || kitDirName.StartsWith('\\')
                     || (kitDirName.Length >= 2 && char.IsAsciiLetter(kitDirName[0]) && kitDirName[1] == ':');
        if (string.IsNullOrWhiteSpace(kitDirName) || rooted || segments.Any(s => s is ".." or ""))
            throw new ArgumentException($"the kit folder '{kitDirName}' must be a relative path without '..'", nameof(kitDirName));
    }
}

namespace DragoAnt.MSBuildKit.Manager.Infrastructure;

/// <summary>Cross-platform path helpers.</summary>
public static class PathUtils
{
    /// <summary>Forward slashes, no leading slash — the shape of a path inside a package.</summary>
    public static string NormalizePath(string path) => path.Replace('\\', '/').TrimStart('/');

    /// <summary>True when <paramref name="path"/> resolves to <paramref name="rootPath"/> or a path beneath it.</summary>
    public static bool IsPathUnderRoot(string path, string rootPath)
    {
        var relative = Path.GetRelativePath(Path.GetFullPath(rootPath), Path.GetFullPath(path));
        return !Path.IsPathRooted(relative)
               && relative != ".."
               && !relative.StartsWith(".." + Path.DirectorySeparatorChar, StringComparison.Ordinal);
    }
}

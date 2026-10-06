using System.Reflection;

namespace DragoAnt.MSBuildKit.Manager.Cli;

/// <summary>The tool's name and version.</summary>
public static class ToolInfo
{
    /// <summary>The command a user types.</summary>
    public const string CommandName = "mskit-manager";

    /// <summary>The package version, without build metadata.</summary>
    public static string Version { get; } = ReadVersion();

    private static string ReadVersion()
    {
        var assembly = typeof(ToolInfo).Assembly;
        var informational = assembly.GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion;
        if (informational is not null)
            return informational.Split('+')[0];

        var version = assembly.GetName().Version;
        return version is null ? "0.0.0" : $"{version.Major}.{version.Minor}.{version.Build}";
    }
}

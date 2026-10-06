using System.ComponentModel;
using Spectre.Console.Cli;

namespace DragoAnt.MSBuildKit.Manager.Cli.Settings;

/// <summary>Options of <c>status</c>.</summary>
public sealed class StatusSettings : CommandSettings
{
    /// <summary>Print JSON instead of text.</summary>
    [CommandOption("--json")]
    [Description("Print JSON instead of text.")]
    public bool Json { get; init; }
}

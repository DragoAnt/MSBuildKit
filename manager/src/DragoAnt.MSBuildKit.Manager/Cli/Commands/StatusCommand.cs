using System.Text.Json;
using DragoAnt.MSBuildKit.Manager.Cli.Settings;
using Microsoft.Extensions.Logging;
using Spectre.Console.Cli;

namespace DragoAnt.MSBuildKit.Manager.Cli.Commands;

internal sealed class StatusCommand(ToolConsole _console, ILogger<StatusCommand> _logger) : Command<StatusSettings>
{
    private static readonly JsonSerializerOptions JsonOptions = new() { PropertyNamingPolicy = JsonNamingPolicy.CamelCase, WriteIndented = true };

    public override int Execute(CommandContext context, StatusSettings settings, CancellationToken cancellationToken)
    {
        _logger.LogInformation("{Tool} {Version}", ToolInfo.CommandName, ToolInfo.Version);

        _console.Out.WriteLine(settings.Json
            ? JsonSerializer.Serialize(new StatusJson(new ToolJson(ToolInfo.CommandName, ToolInfo.Version)), JsonOptions)
            : $"{ToolInfo.CommandName} {ToolInfo.Version}");
        return 0;
    }

    private sealed record StatusJson(ToolJson Tool);

    private sealed record ToolJson(string Name, string Version);
}

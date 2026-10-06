using Spectre.Console.Cli;

namespace DragoAnt.MSBuildKit.Manager.Logging;

/// <summary>Names the log file after the command the parser chose, so a new command needs no registration here.</summary>
internal sealed class CommandLogInterceptor(LogSession _session) : ICommandInterceptor
{
    public void Intercept(CommandContext context, CommandSettings settings) => _session.Open(context.Name);
}

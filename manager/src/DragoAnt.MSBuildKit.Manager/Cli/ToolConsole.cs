namespace DragoAnt.MSBuildKit.Manager.Cli;

/// <summary>Where a run writes: <see cref="Out"/> carries results only; the logo, progress and errors go to <see cref="Error"/>.</summary>
/// <param name="Out">Results — what a script or <c>--json</c> reader consumes.</param>
/// <param name="Error">Everything meant for a person.</param>
/// <param name="ErrorIsTerminal">True when <see cref="Error"/> is an interactive terminal.</param>
public sealed record ToolConsole(TextWriter Out, TextWriter Error, bool ErrorIsTerminal)
{
    /// <summary>The process's own streams.</summary>
    public static ToolConsole System => new(Console.Out, Console.Error, !Console.IsErrorRedirected);
}

namespace DragoAnt.MSBuildKit.Manager.Cli;

/// <summary>Options every command accepts, anywhere on the command line. They are read before the command
/// parser runs, because the logo and the log are set up first.</summary>
/// <param name="NoLogo"><c>--no-logo</c>: never print the logo.</param>
/// <param name="Diagnostic"><c>--diagnostic</c>: mirror debug events with <c>--log-to-console</c>.</param>
/// <param name="LogToConsole"><c>--log-to-console</c>: mirror the log to stderr.</param>
/// <param name="NoColor"><c>--no-color</c>: plain text output.</param>
public sealed record GlobalOptions(bool NoLogo = false, bool Diagnostic = false, bool LogToConsole = false, bool NoColor = false)
{
    /// <summary>Reads the global flags and returns the arguments left for the commands, in their order.</summary>
    public static (GlobalOptions Options, string[] Remaining) Parse(IReadOnlyList<string> args)
    {
        var options = new GlobalOptions();
        var remaining = new List<string>(args.Count);
        foreach (var arg in args)
        {
            switch (arg.ToLowerInvariant())
            {
                case "--no-logo":
                    options = options with { NoLogo = true };
                    break;
                case "--diagnostic":
                    options = options with { Diagnostic = true };
                    break;
                case "--log-to-console":
                    options = options with { LogToConsole = true };
                    break;
                case "--no-color":
                    options = options with { NoColor = true };
                    break;
                default:
                    remaining.Add(arg);
                    break;
            }
        }

        return (options, remaining.ToArray());
    }
}

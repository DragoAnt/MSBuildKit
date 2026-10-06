namespace DragoAnt.MSBuildKit.Manager.Cli;

public sealed record ToolConsole(TextWriter Out, TextWriter Error, bool ErrorIsTerminal);

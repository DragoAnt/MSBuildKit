namespace DragoAnt.MSBuildKit.Manager.Cli;

public sealed record GlobalOptions(bool NoLogo = false, bool Diagnostic = false, bool LogToConsole = false, bool NoColor = false)
{
    public static (GlobalOptions Options, string[] Remaining) Parse(IReadOnlyList<string> args) => throw new NotImplementedException();
}

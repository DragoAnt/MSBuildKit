namespace DragoAnt.MSBuildKit.Manager.Cli;

internal static class Logo
{
    private const string Ink = "\x1b[38;2;46;139;87m";
    private const string Accent = "\x1b[38;2;218;165;32m";
    private const string Dim = "\x1b[90m";
    private const string Reset = "\x1b[0m";

    // stdout carries results only, so the logo goes to stderr, and only when a person is watching it.
    public static bool ShouldWrite(GlobalOptions options, bool errorIsTerminal) => !options.NoLogo && errorIsTerminal;

    public static void Write(TextWriter error, string version, bool color)
    {
        string Paint(string code, string text) => color ? code + text + Reset : text;

        error.WriteLine(" " + Paint(Ink, "╔╦╗╔═╗╦╔═╦╔╦╗") + "   " + Paint(Accent, $"{ToolInfo.CommandName} {version}"));
        error.WriteLine(" " + Paint(Ink, "║║║╚═╗╠╩╗║ ║ ") + "   " + Paint(Dim, "DragoAnt MSBuildKit for .NET repositories"));
        error.WriteLine(" " + Paint(Ink, "╩ ╩╚═╝╩ ╩╩ ╩ "));
        error.WriteLine();
    }
}

using System.Text.Json;
using DragoAnt.MSBuildKit.Manager.Cli;

namespace DragoAnt.MSBuildKit.Manager.Tests;

public sealed class ProgramTests
{
    private sealed record Run(int ExitCode, string Out, string Error);

    private static Run Invoke(TempDirectory logs, bool errorIsTerminal, params string[] args)
    {
        var console = new ToolConsole(new StringWriter(), new StringWriter(), errorIsTerminal);
        var exitCode = Program.Run(args, console, logs.Path);
        return new Run(exitCode, console.Out.ToString()!, console.Error.ToString()!);
    }

    [Fact]
    public void StatusJson_OnATerminal_KeepsTheLogoOffStdout()
    {
        using var logs = new TempDirectory();

        var run = Invoke(logs, errorIsTerminal: true, "status", "--json");

        run.ExitCode.Should().Be(0, run.Error);
        using var json = JsonDocument.Parse(run.Out);
        var tool = json.RootElement.GetProperty("tool");
        tool.GetProperty("name").GetString().Should().Be("mskit-manager");
        tool.GetProperty("version").GetString().Should().Be(ToolInfo.Version);
        run.Error.Should().Contain("mskit-manager " + ToolInfo.Version);
    }

    [Fact]
    public void Logo_IsSkippedWithNoLogo()
    {
        using var logs = new TempDirectory();

        var run = Invoke(logs, errorIsTerminal: true, "--no-logo", "status", "--json");

        run.ExitCode.Should().Be(0, run.Error);
        run.Error.Should().BeEmpty();
    }

    [Fact]
    public void Logo_IsSkippedWhenStderrIsRedirected()
    {
        using var logs = new TempDirectory();

        var run = Invoke(logs, errorIsTerminal: false, "status", "--json");

        run.ExitCode.Should().Be(0, run.Error);
        run.Error.Should().BeEmpty();
    }

    [Fact]
    public void Status_WithoutJson_PrintsTheVersionLine()
    {
        using var logs = new TempDirectory();

        var run = Invoke(logs, errorIsTerminal: false, "status");

        run.ExitCode.Should().Be(0, run.Error);
        run.Out.Trim().Should().Be("mskit-manager " + ToolInfo.Version);
    }

    [Fact]
    public void LogFile_IsNamedAfterTheParsedCommand_AndRecordsTheRun()
    {
        using var logs = new TempDirectory();

        Invoke(logs, errorIsTerminal: false, "--diagnostic", "status", "--json");

        var file = Directory.GetFiles(logs.Path, "*.log").Should().ContainSingle().Subject;
        Path.GetFileName(file).Should().EndWith("-status.log");
        File.ReadAllText(file).Should().Contain(ToolInfo.Version);
    }

    [Fact]
    public void Help_ListsTheStatusCommand()
    {
        using var logs = new TempDirectory();

        var run = Invoke(logs, errorIsTerminal: false, "--help");

        run.ExitCode.Should().Be(0, run.Error);
        run.Out.Should().Contain("status");
    }

    [Fact]
    public void UnknownCommand_IsAUsageErrorWithExitCode2()
    {
        using var logs = new TempDirectory();

        var run = Invoke(logs, errorIsTerminal: false, "no-such-command");

        run.ExitCode.Should().Be(2);
        run.Error.Should().Contain("no-such-command");
        run.Out.Should().BeEmpty();
    }
}

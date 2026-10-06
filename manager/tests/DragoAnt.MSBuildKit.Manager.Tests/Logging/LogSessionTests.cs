using DragoAnt.MSBuildKit.Manager.Logging;
using Microsoft.Extensions.Logging;

namespace DragoAnt.MSBuildKit.Manager.Tests.Logging;

public sealed class LogSessionTests
{
    [Fact]
    public void Open_NamesTheFileAfterTheCommand()
    {
        using var dir = new TempDirectory();
        string path;
        using (var session = LogSession.Create(dir.Path, LogLevel.Information, consoleWriter: null))
        {
            session.Open("status");
            path = session.FilePath!;
        }

        Path.GetDirectoryName(path).Should().Be(dir.Path);
        Path.GetFileName(path).Should().MatchRegex(@"^\d{8}-\d{6}-\d{3}-status\.log$");
    }

    [Fact]
    public void Open_KeepsTheNewestTwentyFiles()
    {
        using var dir = new TempDirectory();
        for (var i = 0; i < 25; i++)
            File.WriteAllText(Path.Combine(dir.Path, $"20200101-0000{i:00}-000-old.log"), "x");
        File.WriteAllText(Path.Combine(dir.Path, "notes.txt"), "not a log");

        using (var session = LogSession.Create(dir.Path, LogLevel.Information, consoleWriter: null))
            session.Open("status");

        var logs = Directory.GetFiles(dir.Path, "*.log").Select(Path.GetFileName).ToList();
        logs.Should().HaveCount(LogSession.KeptFiles);
        logs.Should().Contain(f => f!.EndsWith("-status.log"));
        logs.Should().NotContain("20200101-000000-000-old.log");
        File.Exists(Path.Combine(dir.Path, "notes.txt")).Should().BeTrue();
    }

    [Fact]
    public void Events_LoggedBeforeOpen_ReachTheFile()
    {
        using var dir = new TempDirectory();
        string path;
        using (var session = LogSession.Create(dir.Path, LogLevel.Information, consoleWriter: null))
        {
            session.Logger.Information("early event");
            session.Open("status");
            session.Logger.Information("late event");
            path = session.FilePath!;
        }

        File.ReadAllText(path).Should().Contain("early event").And.Contain("late event");
    }

    [Fact]
    public void EnsureOpen_WhenNoCommandWasParsed_FallsBackToTool()
    {
        using var dir = new TempDirectory();
        using var session = LogSession.Create(dir.Path, LogLevel.Information, consoleWriter: null);

        Path.GetFileName(session.EnsureOpen()).Should().EndWith("-tool.log");
    }

    [Fact]
    public void File_TakesEveryLevel_WithoutAConsoleSink()
    {
        using var dir = new TempDirectory();
        string path;
        using (var session = LogSession.Create(dir.Path, LogLevel.Information, consoleWriter: null))
        {
            session.Open("status");
            session.Logger.Debug("debug for the file");
            path = session.FilePath!;
        }

        File.ReadAllText(path).Should().Contain("debug for the file");
    }

    [Theory]
    [InlineData(LogLevel.Debug, true)]
    [InlineData(LogLevel.Information, false)]
    public void Console_WhenEnabled_IsGatedByItsLevel(LogLevel consoleLevel, bool debugVisible)
    {
        using var dir = new TempDirectory();
        var console = new StringWriter();
        using (var session = LogSession.Create(dir.Path, consoleLevel, console))
        {
            session.Open("status");
            session.Logger.Information("info line");
            session.Logger.Debug("debug line");
        }

        console.ToString().Should().Contain("info line");
        console.ToString().Contains("debug line").Should().Be(debugVisible);
    }

    [Fact]
    public void WriteFailureFooter_NamesTheLogFile()
    {
        var error = new StringWriter();

        LogSession.WriteFailureFooter(error, "/logs/x-status.log");

        error.ToString().Should().Contain("/logs/x-status.log").And.Contain("failed");
    }
}

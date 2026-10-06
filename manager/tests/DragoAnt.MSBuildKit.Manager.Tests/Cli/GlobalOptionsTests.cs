using DragoAnt.MSBuildKit.Manager.Cli;

namespace DragoAnt.MSBuildKit.Manager.Tests.Cli;

public sealed class GlobalOptionsTests
{
    [Fact]
    public void Parse_ReadsEveryFlagAndLeavesTheRestForTheCommands()
    {
        var (options, remaining) = GlobalOptions.Parse(["--no-logo", "status", "--diagnostic", "--json", "--log-to-console", "--no-color"]);

        options.Should().Be(new GlobalOptions(NoLogo: true, Diagnostic: true, LogToConsole: true, NoColor: true));
        remaining.Should().Equal("status", "--json");
    }

    [Fact]
    public void Parse_IsCaseInsensitiveAndRemovesEveryOccurrence()
    {
        var (options, remaining) = GlobalOptions.Parse(["--NO-LOGO", "status", "--no-logo"]);

        options.NoLogo.Should().BeTrue();
        remaining.Should().Equal("status");
    }

    [Fact]
    public void Parse_KeepsAValueThatOnlyContainsAFlag()
    {
        var (options, remaining) = GlobalOptions.Parse(["status", "--name=--no-logo"]);

        options.NoLogo.Should().BeFalse();
        remaining.Should().Equal("status", "--name=--no-logo");
    }
}

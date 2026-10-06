using DragoAnt.MSBuildKit.Manager.Cli;

namespace DragoAnt.MSBuildKit.Manager.Tests.Cli;

public sealed class LogoTests
{
    [Theory]
    [InlineData(false, true, true)]
    [InlineData(true, true, false)]
    [InlineData(false, false, false)]
    public void ShouldWrite_OnlyOnATerminalWithoutNoLogo(bool noLogo, bool errorIsTerminal, bool expected) =>
        Logo.ShouldWrite(new GlobalOptions(NoLogo: noLogo), errorIsTerminal).Should().Be(expected);

    [Fact]
    public void Write_NamesTheToolAndVersion_WithoutColorWhenAsked()
    {
        var error = new StringWriter();

        Logo.Write(error, "1.2.3", color: false);

        error.ToString().Should().Contain("mskit-manager 1.2.3").And.Contain("MSBuildKit").And.NotContain("\x1b[");
    }

    [Fact]
    public void Write_WithColor_ResetsTheTerminalAtTheEnd()
    {
        var error = new StringWriter();

        Logo.Write(error, "1.2.3", color: true);

        error.ToString().TrimEnd().Should().EndWith("\x1b[0m");
    }
}

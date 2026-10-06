using DragoAnt.MSBuildKit.Manager.Infrastructure;

namespace DragoAnt.MSBuildKit.Manager.Tests.Infrastructure;

public sealed class ProcessRunnerTests
{
    [Fact]
    public async Task RunAsync_WhenChildSucceeds_CapturesStdOutAndExitCode()
    {
        var result = await new ProcessRunner().RunAsync("dotnet", "--version", ct: TestContext.Current.CancellationToken);

        result.Success.Should().BeTrue(result.StdErr);
        result.StdOut.Should().MatchRegex(@"^\d+\.\d+\.\d+");
    }

    [Fact]
    public async Task RunWithCallbacksAsync_StreamsEveryLineAndStillCapturesIt()
    {
        var lines = new List<string>();

        var result = await new ProcessRunner().RunWithCallbacksAsync(
            "dotnet", "--version", null, line => { lock (lines) lines.Add(line); }, _ => { },
            TestContext.Current.CancellationToken);

        lines.Should().ContainSingle().Which.Should().Be(result.StdOut);
    }

    [Fact]
    public async Task RunAsync_WhenChildFails_ReportsItsExitCode()
    {
        var result = await new ProcessRunner().RunAsync("dotnet", "no-such-command-xyz", ct: TestContext.Current.CancellationToken);

        result.Success.Should().BeFalse();
        result.ExitCode.Should().NotBe(0);
    }
}

using DragoAnt.MSBuildKit.Manager.Infrastructure;

namespace DragoAnt.MSBuildKit.Manager.Tests.Infrastructure;

public sealed class ProcessResultExitDescriptionTests
{
    [Theory]
    [InlineData(139, "SIGSEGV")]
    [InlineData(137, "SIGKILL")]
    [InlineData(143, "SIGTERM")]
    [InlineData(134, "SIGABRT")]
    [InlineData(141, "SIGPIPE")]
    public void DescribeExitCode_WhenUnixSignalRange_NamesTheSignal(int exitCode, string signal)
    {
        var described = ProcessResult.DescribeExitCode(exitCode, isWindows: false);

        described.Should().Contain(exitCode.ToString()).And.Contain(signal);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(1)]
    [InlineData(3)]
    [InlineData(128)]
    [InlineData(255)]
    public void DescribeExitCode_WhenOutsideSignalRange_StaysPlainExitCode(int exitCode) =>
        ProcessResult.DescribeExitCode(exitCode, isWindows: false).Should().Be($"exit {exitCode}");

    [Fact]
    public void DescribeExitCode_WhenSignalUnmapped_StillReportsTheSignalNumber() =>
        ProcessResult.DescribeExitCode(128 + 31, isWindows: false).Should().Contain("signal 31");

    [Fact]
    public void DescribeExitCode_OnWindows_NeverReadsASignal() =>
        ProcessResult.DescribeExitCode(139, isWindows: true).Should().Be("exit 139");

    [Fact]
    public void ExitDescription_ReportsTheInstanceExitCode() =>
        new ProcessResult { ExitCode = 0 }.ExitDescription.Should().Be("exit 0");
}

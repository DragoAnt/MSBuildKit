namespace DragoAnt.MSBuildKit.Manager.Infrastructure;

public sealed class ProcessResult
{
    public int ExitCode { get; init; }

    public string StdOut { get; init; } = "";

    public string StdErr { get; init; } = "";

    public bool Success => ExitCode == 0;

    public string ExitDescription => DescribeExitCode(ExitCode);

    public static string DescribeExitCode(int exitCode) => DescribeExitCode(exitCode, OperatingSystem.IsWindows());

    internal static string DescribeExitCode(int exitCode, bool isWindows) => throw new NotImplementedException();
}

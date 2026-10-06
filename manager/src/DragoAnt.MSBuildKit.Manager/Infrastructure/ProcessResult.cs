namespace DragoAnt.MSBuildKit.Manager.Infrastructure;

/// <summary>Captured outcome of a child-process run.</summary>
public sealed class ProcessResult
{
    /// <summary>Process exit code reported by the OS.</summary>
    public int ExitCode { get; init; }

    /// <summary>Captured standard output, trailing whitespace trimmed.</summary>
    public string StdOut { get; init; } = "";

    /// <summary>Captured standard error, trailing whitespace trimmed.</summary>
    public string StdErr { get; init; } = "";

    /// <summary>True when <see cref="ExitCode"/> is zero.</summary>
    public bool Success => ExitCode == 0;

    /// <summary><see cref="ExitCode"/> rendered for a reader, naming the POSIX signal behind it where there is one.</summary>
    public string ExitDescription => DescribeExitCode(ExitCode);

    /// <summary>Renders <paramref name="exitCode"/>, expanding the 128+N range into the signal that produced it.</summary>
    /// <remarks>A child killed by a signal leaves only 128 + the signal number and nothing on stderr. A script can return
    /// that number on its own, so the signal is named as the shape of the code, not asserted as what happened.</remarks>
    public static string DescribeExitCode(int exitCode) => DescribeExitCode(exitCode, OperatingSystem.IsWindows());

    internal static string DescribeExitCode(int exitCode, bool isWindows)
    {
        if (isWindows || exitCode <= 128 || exitCode > 128 + 64)
            return $"exit {exitCode}";

        var signal = exitCode - 128;
        var name = signal switch
        {
            1 => "SIGHUP",
            2 => "SIGINT",
            3 => "SIGQUIT",
            4 => "SIGILL",
            6 => "SIGABRT",
            8 => "SIGFPE",
            9 => "SIGKILL",
            11 => "SIGSEGV",
            13 => "SIGPIPE",
            15 => "SIGTERM",
            _ => $"signal {signal}",
        };

        return $"exit {exitCode} — 128+{signal}, the shape of a child killed by {name}";
    }
}

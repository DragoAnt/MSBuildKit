namespace DragoAnt.MSBuildKit.Manager.Infrastructure;

/// <summary>Starts child processes; the seam tests replace.</summary>
public interface IProcessRunner
{
    /// <summary>Starts <paramref name="fileName"/>, captures both output streams and awaits exit.</summary>
    /// <param name="fileName">Executable to launch, resolved through <c>PATH</c>.</param>
    /// <param name="arguments">Command-line arguments for the child.</param>
    /// <param name="workingDirectory">Working directory of the child; the current directory when null.</param>
    /// <param name="ct">Cancels the wait.</param>
    Task<ProcessResult> RunAsync(string fileName, string arguments, string? workingDirectory = null, CancellationToken ct = default);

    /// <summary>As <see cref="RunAsync"/>, also invoking a callback per output line as it arrives.</summary>
    /// <remarks>Callbacks run on thread-pool threads; one that throws is ignored so the streams keep draining.</remarks>
    /// <param name="fileName">Executable to launch, resolved through <c>PATH</c>.</param>
    /// <param name="arguments">Command-line arguments for the child.</param>
    /// <param name="workingDirectory">Working directory of the child; the current directory when null.</param>
    /// <param name="onStdout">Called once per standard-output line.</param>
    /// <param name="onStderr">Called once per standard-error line.</param>
    /// <param name="ct">Cancels the wait.</param>
    Task<ProcessResult> RunWithCallbacksAsync(string fileName, string arguments, string? workingDirectory,
        Action<string> onStdout, Action<string> onStderr, CancellationToken ct = default);
}

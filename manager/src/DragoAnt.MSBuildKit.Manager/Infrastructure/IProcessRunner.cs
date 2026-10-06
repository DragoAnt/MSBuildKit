namespace DragoAnt.MSBuildKit.Manager.Infrastructure;

public interface IProcessRunner
{
    Task<ProcessResult> RunAsync(string fileName, string arguments, string? workingDirectory = null, CancellationToken ct = default);

    Task<ProcessResult> RunWithCallbacksAsync(string fileName, string arguments, string? workingDirectory,
        Action<string> onStdout, Action<string> onStderr, CancellationToken ct = default);
}

namespace DragoAnt.MSBuildKit.Manager.Infrastructure;

public sealed class ProcessRunner : IProcessRunner
{
    public Task<ProcessResult> RunAsync(string fileName, string arguments, string? workingDirectory = null, CancellationToken ct = default) =>
        throw new NotImplementedException();

    public Task<ProcessResult> RunWithCallbacksAsync(string fileName, string arguments, string? workingDirectory,
        Action<string> onStdout, Action<string> onStderr, CancellationToken ct = default) =>
        throw new NotImplementedException();
}

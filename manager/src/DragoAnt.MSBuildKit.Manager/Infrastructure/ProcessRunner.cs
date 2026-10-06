using System.Diagnostics;
using System.Text;

namespace DragoAnt.MSBuildKit.Manager.Infrastructure;

/// <summary>Runs <c>dotnet</c>, <c>git</c> and other children through <see cref="Process"/>, stdin closed.</summary>
public sealed class ProcessRunner : IProcessRunner
{
    /// <inheritdoc />
    public Task<ProcessResult> RunAsync(string fileName, string arguments, string? workingDirectory = null, CancellationToken ct = default) =>
        RunWithCallbacksAsync(fileName, arguments, workingDirectory, static _ => { }, static _ => { }, ct);

    /// <inheritdoc />
    public async Task<ProcessResult> RunWithCallbacksAsync(string fileName, string arguments, string? workingDirectory,
        Action<string> onStdout, Action<string> onStderr, CancellationToken ct = default)
    {
        ArgumentNullException.ThrowIfNull(onStdout);
        ArgumentNullException.ThrowIfNull(onStderr);

        using var process = new Process
        {
            StartInfo = new ProcessStartInfo
            {
                FileName = fileName,
                Arguments = arguments,
                WorkingDirectory = workingDirectory ?? Directory.GetCurrentDirectory(),
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                // A child that reads stdin would otherwise block on the shared console and never exit.
                RedirectStandardInput = true,
                UseShellExecute = false,
                CreateNoWindow = true,
            },
        };
        var stdout = new StringBuilder();
        var stderr = new StringBuilder();
        process.OutputDataReceived += (_, e) => Collect(e.Data, stdout, onStdout);
        process.ErrorDataReceived += (_, e) => Collect(e.Data, stderr, onStderr);

        process.Start();
        try
        {
            process.StandardInput.Close();
        }
        catch (IOException)
        {
        }

        process.BeginOutputReadLine();
        process.BeginErrorReadLine();
        await process.WaitForExitAsync(ct);

        return new ProcessResult
        {
            ExitCode = process.ExitCode,
            StdOut = stdout.ToString().TrimEnd(),
            StdErr = stderr.ToString().TrimEnd(),
        };
    }

    private static void Collect(string? line, StringBuilder buffer, Action<string> callback)
    {
        if (line is null)
            return;

        lock (buffer)
            buffer.AppendLine(line);

        try
        {
            callback(line);
        }
        catch (Exception)
        {
            // The streams must keep draining or the child blocks on a full pipe.
        }
    }
}

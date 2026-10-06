using Microsoft.Extensions.Logging;

namespace DragoAnt.MSBuildKit.Manager.Logging;

public sealed class LogSession : IDisposable
{
    public const int KeptFiles = 20;

    public Serilog.ILogger Logger => throw new NotImplementedException();

    public string? FilePath => throw new NotImplementedException();

    public static LogSession Create(string logDirectory, LogLevel consoleLevel, TextWriter? consoleWriter) =>
        throw new NotImplementedException();

    public void Open(string commandName) => throw new NotImplementedException();

    public string EnsureOpen() => throw new NotImplementedException();

    public static void WriteFailureFooter(TextWriter error, string logFilePath) => throw new NotImplementedException();

    public void Dispose()
    {
    }
}

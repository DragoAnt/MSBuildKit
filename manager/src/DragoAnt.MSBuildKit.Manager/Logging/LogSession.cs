using System.Globalization;
using Microsoft.Extensions.Logging;
using Serilog;
using Serilog.Core;
using Serilog.Events;
using Serilog.Formatting.Compact;
using Serilog.Formatting.Display;

namespace DragoAnt.MSBuildKit.Manager.Logging;

/// <summary>The run's log: one CompactJson file per invocation, named after the parsed command, newest
/// <see cref="KeptFiles"/> kept. Events logged before the command is known are held and written on <see cref="Open"/>.</summary>
public sealed class LogSession : IDisposable
{
    /// <summary>How many log files the folder keeps, the new one included.</summary>
    public const int KeptFiles = 20;

    private const string FallbackCommand = "tool";

    private readonly string _directory;
    private readonly DeferredFileSink _file = new();
    private readonly Logger _logger;

    private LogSession(string directory, LogLevel consoleLevel, TextWriter? consoleWriter)
    {
        _directory = directory;
        var config = new LoggerConfiguration()
            .MinimumLevel.Verbose()
            .Enrich.FromLogContext()
            .WriteTo.Sink(_file);
        if (consoleWriter is not null)
            config = config.WriteTo.Sink(new TextWriterSink(consoleWriter), ToSerilogLevel(consoleLevel));
        _logger = config.CreateLogger();
    }

    /// <summary>The default folder: <c>&lt;system temp&gt;/mskit-manager/logs</c>.</summary>
    public static string DefaultDirectory => Path.Combine(Path.GetTempPath(), "mskit-manager", "logs");

    /// <summary>The process logger.</summary>
    public Serilog.ILogger Logger => _logger;

    /// <summary>The log file, or null until <see cref="Open"/>.</summary>
    public string? FilePath => _file.Path;

    /// <summary>Starts a session; nothing touches the disk until <see cref="Open"/>.</summary>
    /// <param name="logDirectory">Folder for the log files.</param>
    /// <param name="consoleLevel">Minimum level mirrored to <paramref name="consoleWriter"/>.</param>
    /// <param name="consoleWriter">Mirror of the log for <c>--log-to-console</c>; null for none.</param>
    public static LogSession Create(string logDirectory, LogLevel consoleLevel, TextWriter? consoleWriter) =>
        new(logDirectory, consoleLevel, consoleWriter);

    /// <summary>Creates the file for <paramref name="commandName"/> and writes the held events; later calls do nothing.</summary>
    public void Open(string commandName) => _file.Open(_directory, commandName);

    /// <summary>The log file path, opening it under the fallback name when no command was parsed.</summary>
    public string EnsureOpen()
    {
        _file.Open(_directory, FallbackCommand);
        return _file.Path!;
    }

    /// <summary>Tells the user where the log of a failed run is.</summary>
    public static void WriteFailureFooter(TextWriter error, string logFilePath)
    {
        error.WriteLine();
        error.WriteLine($"mskit-manager failed — see {logFilePath}");
    }

    /// <inheritdoc />
    public void Dispose()
    {
        _logger.Dispose();
        _file.Dispose();
    }

    private static LogEventLevel ToSerilogLevel(LogLevel level) => level switch
    {
        LogLevel.Trace => LogEventLevel.Verbose,
        LogLevel.Debug => LogEventLevel.Debug,
        LogLevel.Information => LogEventLevel.Information,
        LogLevel.Warning => LogEventLevel.Warning,
        LogLevel.Error => LogEventLevel.Error,
        _ => LogEventLevel.Fatal,
    };

    private sealed class TextWriterSink(TextWriter _writer) : ILogEventSink
    {
        private readonly MessageTemplateTextFormatter _formatter = new("{Message:lj}{NewLine}{Exception}", CultureInfo.InvariantCulture);

        public void Emit(LogEvent logEvent)
        {
            lock (_writer)
                _formatter.Format(logEvent, _writer);
        }
    }

    private sealed class DeferredFileSink : ILogEventSink, IDisposable
    {
        private readonly object _gate = new();
        private readonly List<LogEvent> _pending = [];
        private Logger? _file;

        public string? Path { get; private set; }

        public void Emit(LogEvent logEvent)
        {
            lock (_gate)
            {
                if (_file is null)
                    _pending.Add(logEvent);
                else
                    _file.Write(logEvent);
            }
        }

        public void Open(string directory, string commandName)
        {
            lock (_gate)
            {
                if (_file is not null)
                    return;

                Directory.CreateDirectory(directory);
                Prune(directory);
                Path = NewFilePath(directory, string.IsNullOrWhiteSpace(commandName) ? FallbackCommand : commandName);
                _file = new LoggerConfiguration()
                    .MinimumLevel.Verbose()
                    .WriteTo.File(new CompactJsonFormatter(), Path)
                    .CreateLogger();
                foreach (var pending in _pending)
                    _file.Write(pending);
                _pending.Clear();
            }
        }

        public void Dispose()
        {
            lock (_gate)
                _file?.Dispose();
        }

        private static string NewFilePath(string directory, string commandName)
        {
            var stamp = DateTime.UtcNow.ToString("yyyyMMdd-HHmmss-fff", CultureInfo.InvariantCulture);
            var path = System.IO.Path.Combine(directory, $"{stamp}-{commandName}.log");
            for (var n = 2; File.Exists(path); n++)
                path = System.IO.Path.Combine(directory, $"{stamp}-{commandName}-{n}.log");
            return path;
        }

        private static void Prune(string directory)
        {
            var stale = Directory.GetFiles(directory, "*.log")
                .OrderByDescending(System.IO.Path.GetFileName, StringComparer.Ordinal)
                .Skip(KeptFiles - 1);
            foreach (var file in stale)
            {
                try
                {
                    File.Delete(file);
                }
                catch (IOException)
                {
                    // Another run still writes it; the next run prunes it.
                }
                catch (UnauthorizedAccessException)
                {
                }
            }
        }
    }
}

using System.Text;
using DragoAnt.MSBuildKit.Manager.Cli;
using DragoAnt.MSBuildKit.Manager.Cli.Commands;
using DragoAnt.MSBuildKit.Manager.Infrastructure;
using DragoAnt.MSBuildKit.Manager.Logging;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Serilog;
using Spectre.Console;
using Spectre.Console.Cli;

namespace DragoAnt.MSBuildKit.Manager;

/// <summary>The <c>mskit-manager</c> host: logo, log, services and the command app.</summary>
public static class Program
{
    /// <summary>Exit code of a usage error: an unknown command or option, a bad value.</summary>
    public const int UsageError = 2;

    /// <summary>Runs the command line and exits with its code.</summary>
    public static int Main(string[] args)
    {
        Console.OutputEncoding = Encoding.UTF8;
        var exitCode = Run(args, ToolConsole.System, LogSession.DefaultDirectory);
        Console.Out.Flush();
        Console.Error.Flush();
        // With a real console attached, a console-input thread can outlive the work and keep the process alive.
        Environment.Exit(exitCode);
        return exitCode;
    }

    internal static int Run(string[] args, ToolConsole console, string logDirectory)
    {
        var (options, commandArgs) = GlobalOptions.Parse(args);
        if (Logo.ShouldWrite(options, console.ErrorIsTerminal))
            Logo.Write(console.Error, ToolInfo.Version, color: !options.NoColor);

        using var session = LogSession.Create(logDirectory,
            options.Diagnostic ? LogLevel.Debug : LogLevel.Information,
            options.LogToConsole ? console.Error : null);

        var services = new ServiceCollection();
        services.AddLogging(builder => builder.SetMinimumLevel(LogLevel.Trace).AddSerilog(session.Logger));
        services.AddSingleton(console);
        services.AddSingleton<IProcessRunner, ProcessRunner>();

        var app = new CommandApp(new DependencyInjectionTypeRegistrar(services));
        app.Configure(config =>
        {
            config.SetApplicationName(ToolInfo.CommandName);
            config.SetApplicationVersion(ToolInfo.Version);
            config.ConfigureConsole(CreateAnsiConsole(console.Out, options.NoColor));
            config.SetInterceptor(new CommandLogInterceptor(session));
            config.SetExceptionHandler((exception, _) => HandleException(exception, console, session));

            config.AddCommand<StatusCommand>("status")
                .WithDescription("Show the tool version.");
        });

        return app.Run(commandArgs);
    }

    private static int HandleException(Exception exception, ToolConsole console, LogSession session)
    {
        if (exception is CommandAppException)
        {
            console.Error.WriteLine($"error: {exception.Message}");
            return UsageError;
        }

        session.Logger.Fatal(exception, "{Tool} failed", ToolInfo.CommandName);
        LogSession.WriteFailureFooter(console.Error, session.EnsureOpen());
        return 1;
    }

    private static IAnsiConsole CreateAnsiConsole(TextWriter output, bool noColor) =>
        AnsiConsole.Create(new AnsiConsoleSettings
        {
            Out = new AnsiConsoleOutput(output),
            Ansi = noColor ? AnsiSupport.No : AnsiSupport.Detect,
            ColorSystem = noColor ? ColorSystemSupport.NoColors : ColorSystemSupport.Detect,
            Interactive = InteractionSupport.No,
        });
}

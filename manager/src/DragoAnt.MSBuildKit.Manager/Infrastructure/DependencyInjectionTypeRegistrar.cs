using Microsoft.Extensions.DependencyInjection;
using Spectre.Console.Cli;

namespace DragoAnt.MSBuildKit.Manager.Infrastructure;

/// <summary>Lets <see cref="CommandApp"/> resolve commands from an <see cref="IServiceCollection"/>; everything is a singleton.</summary>
public sealed class DependencyInjectionTypeRegistrar(IServiceCollection _services) : ITypeRegistrar
{
    /// <inheritdoc />
    public ITypeResolver Build() => new DependencyInjectionTypeResolver(_services.BuildServiceProvider());

    /// <inheritdoc />
    public void Register(Type service, Type implementation) => _services.AddSingleton(service, implementation);

    /// <inheritdoc />
    public void RegisterInstance(Type service, object implementation) => _services.AddSingleton(service, implementation);

    /// <inheritdoc />
    public void RegisterLazy(Type service, Func<object> factory)
    {
        ArgumentNullException.ThrowIfNull(factory);
        _services.AddSingleton(service, _ => factory());
    }
}

internal sealed class DependencyInjectionTypeResolver(ServiceProvider _provider) : ITypeResolver, IDisposable
{
    // Spectre expects null for an unregistered type; throwing reads as a crashed resolver.
    public object? Resolve(Type? type) => type is null ? null : _provider.GetService(type);

    public void Dispose() => _provider.Dispose();
}

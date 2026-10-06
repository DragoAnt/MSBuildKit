using DragoAnt.MSBuildKit.Manager.Infrastructure;
using Microsoft.Extensions.DependencyInjection;

namespace DragoAnt.MSBuildKit.Manager.Tests.Infrastructure;

public sealed class DependencyInjectionTypeRegistrarTests
{
    [Fact]
    public void Build_ResolvesRegisteredTypesAndServicesAddedBefore()
    {
        var services = new ServiceCollection();
        services.AddSingleton("added before");
        var registrar = new DependencyInjectionTypeRegistrar(services);
        registrar.Register(typeof(IProcessRunner), typeof(ProcessRunner));
        registrar.RegisterLazy(typeof(Uri), () => new Uri("https://example.org/"));

        var resolver = registrar.Build();

        resolver.Resolve(typeof(IProcessRunner)).Should().BeOfType<ProcessRunner>();
        resolver.Resolve(typeof(Uri)).Should().Be(new Uri("https://example.org/"));
        resolver.Resolve(typeof(string)).Should().Be("added before");
    }

    [Fact]
    public void Resolve_WhenTypeIsNotRegistered_ReturnsNull() =>
        new DependencyInjectionTypeRegistrar(new ServiceCollection()).Build().Resolve(typeof(IProcessRunner)).Should().BeNull();
}

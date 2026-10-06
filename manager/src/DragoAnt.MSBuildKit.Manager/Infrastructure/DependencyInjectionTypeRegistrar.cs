using Microsoft.Extensions.DependencyInjection;
using Spectre.Console.Cli;

namespace DragoAnt.MSBuildKit.Manager.Infrastructure;

public sealed class DependencyInjectionTypeRegistrar(IServiceCollection _services) : ITypeRegistrar
{
    public ITypeResolver Build() => throw new NotImplementedException(_services.Count.ToString());

    public void Register(Type service, Type implementation) => throw new NotImplementedException();

    public void RegisterInstance(Type service, object implementation) => throw new NotImplementedException();

    public void RegisterLazy(Type service, Func<object> factory) => throw new NotImplementedException();
}

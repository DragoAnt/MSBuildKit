namespace DragoAnt.MSBuildKit.Manager.Packages;

/// <summary>A NuGet source a filter's packages come from; <see cref="Patterns"/> become its package source mapping.</summary>
internal sealed record KitFilterSource(string Name, string Url, IReadOnlyList<string> Patterns);

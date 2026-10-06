namespace DragoAnt.MSBuildKit.Manager.Packages;

/// <summary>A package a filter attaches, with an optional NuGet version range.</summary>
internal sealed record KitFilterPackage(string Id, string? Version);

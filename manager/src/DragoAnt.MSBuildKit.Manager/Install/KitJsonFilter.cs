namespace DragoAnt.MSBuildKit.Manager.Install;

/// <summary>A company or team package the repository attached, and the NuGet source it comes from.</summary>
internal sealed record KitJsonFilter(string Package, string? Source);

namespace DragoAnt.MSBuildKit.Manager.Packages;

/// <summary>The core version range and prerelease policy a company allows.</summary>
internal sealed record KitFilterCore(string? Version, bool? Prerelease);

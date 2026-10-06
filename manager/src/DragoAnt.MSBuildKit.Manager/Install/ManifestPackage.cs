namespace DragoAnt.MSBuildKit.Manager.Install;

/// <summary>A package the last install deployed, at its exact version.</summary>
internal sealed record ManifestPackage(string Id, string Version);

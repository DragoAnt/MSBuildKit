namespace DragoAnt.MSBuildKit.Manager.Install;

/// <summary>
/// A deployed file, relative to the kit folder with forward slashes. <see cref="Package"/> is <see langword="null"/>
/// for a file the tool generates (the aggregator).
/// </summary>
internal sealed record ManifestFile(string Path, string? Package, string Sha256);

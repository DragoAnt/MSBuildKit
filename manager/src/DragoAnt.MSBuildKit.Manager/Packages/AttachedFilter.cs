namespace DragoAnt.MSBuildKit.Manager.Packages;

/// <summary>A company or team package attached to the repository, with the filter it ships.</summary>
internal sealed record AttachedFilter(string PackageId, KitFilter Filter);

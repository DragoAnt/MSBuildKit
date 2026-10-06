namespace DragoAnt.MSBuildKit.Manager.Install;

/// <summary>The fields of a schema-1 <c>kit.json</c> (written by <c>update.sh</c>) that schema 2 no longer has.</summary>
internal sealed record KitJsonLegacy(string? Repository, string? Version, string? Sha256);

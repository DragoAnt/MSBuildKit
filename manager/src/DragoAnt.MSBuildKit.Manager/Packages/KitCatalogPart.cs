namespace DragoAnt.MSBuildKit.Manager.Packages;

/// <summary>One core part in the trunk's <c>catalog.json</c>.</summary>
internal sealed record KitCatalogPart(string Id, KitPartKind Kind, int Order, IReadOnlyList<string> Requires);

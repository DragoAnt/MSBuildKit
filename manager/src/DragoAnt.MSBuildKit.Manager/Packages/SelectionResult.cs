namespace DragoAnt.MSBuildKit.Manager.Packages;

/// <summary>The effective selection: every catalog part in order, the attached filters, and the packages they add.</summary>
internal sealed record SelectionResult(
    IReadOnlyList<PartDecision> Parts,
    AttachedFilter? Company,
    AttachedFilter? Team,
    IReadOnlyList<KitFilterPackage> Packages)
{
    public IEnumerable<KitCatalogPart> EnabledParts => Parts.Where(p => p.Enabled).Select(p => p.Part);

    public PartDecision Decision(string id) =>
        Parts.FirstOrDefault(p => p.Id == id) ?? throw new KeyNotFoundException($"part '{id}' is not in the catalog");
}

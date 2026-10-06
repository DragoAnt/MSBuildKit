namespace DragoAnt.MSBuildKit.Manager.Packages;

/// <summary>
/// One part's effective state and the layer that decided it — the data behind <c>parts --explain</c>.
/// <see cref="RequiredBy"/> names the enabled part that pulled this one in through <c>requires</c>.
/// </summary>
internal sealed record PartDecision(KitCatalogPart Part, bool Enabled, SelectionLayer DecidedBy, string? RequiredBy, bool Locked)
{
    public string Id => Part.Id;
}

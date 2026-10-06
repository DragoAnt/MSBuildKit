namespace DragoAnt.MSBuildKit.Manager.Packages;

/// <summary>
/// Computes the effective parts: core catalog defaults, then the company filter, the team filter and the repository's
/// <c>kit.json</c>, a later layer winning per part; then closes the result over <c>requires</c>.
/// </summary>
internal static class Selection
{
    private const string RepositoryName = "the repository (kit.json)";

    public static SelectionResult Compute(KitCatalog catalog, IReadOnlyList<AttachedFilter> filters, PartToggles repository)
    {
        var (company, team) = ResolveFilters(filters);

        var states = catalog.Parts.ToDictionary(
            p => p.Id,
            p => new PartState(p, p.Kind != KitPartKind.Optional, SelectionLayer.Core, "the core catalog"),
            StringComparer.Ordinal);
        var locked = new HashSet<string>(StringComparer.Ordinal);
        string? lockOwner = null;

        if (company is not null)
        {
            var who = Describe(company);
            Apply(catalog, states, SelectionLayer.Company, who, company.Filter.Parts.Enable, company.Filter.Parts.Disable, locked, lockOwner);
            foreach (var id in company.Filter.Parts.Locked)
                locked.Add(RequireKnown(catalog, SelectionLayer.Company, who, id).Id);
            lockOwner = who;
        }

        if (team is not null)
            Apply(catalog, states, SelectionLayer.Team, Describe(team), team.Filter.Parts.Enable, team.Filter.Parts.Disable, locked, lockOwner);

        Apply(catalog, states, SelectionLayer.Repository, RepositoryName, repository.Enable, repository.Disable, locked, lockOwner);

        CloseOverRequires(catalog, states);

        var decisions = catalog.Parts
            .Select(p => states[p.Id])
            .Select(s => new PartDecision(s.Part, s.Enabled, s.Layer, s.RequiredBy, locked.Contains(s.Part.Id)))
            .ToList();
        var packages = new[] { company, team }
            .Where(f => f is not null)
            .SelectMany(f => f!.Filter.Packages)
            .ToList();
        return new SelectionResult(decisions, company, team, packages);
    }

    private static (AttachedFilter? Company, AttachedFilter? Team) ResolveFilters(IReadOnlyList<AttachedFilter> filters)
    {
        if (filters.FirstOrDefault(f => f.Filter.Tier == KitTier.Core) is { } core)
            throw new ArgumentException($"'{core.PackageId}' carries a core-tier filter", nameof(filters));

        var companies = filters.Where(f => f.Filter.Tier == KitTier.Company).ToList();
        if (companies.Count > 1)
            throw new SelectionException(SelectionLayer.Company,
                $"at most one company filter may be attached, found {string.Join(", ", companies.Select(f => $"'{f.PackageId}'"))}");

        var teams = filters.Where(f => f.Filter.Tier == KitTier.Team).ToList();
        if (teams.Count > 1)
            throw new SelectionException(SelectionLayer.Team,
                $"at most one team filter may be attached, found {string.Join(", ", teams.Select(f => $"'{f.PackageId}'"))}");

        var company = companies.SingleOrDefault();
        var team = teams.SingleOrDefault();
        if (team is not null)
        {
            var extends = team.Filter.Extends;
            if (company is null)
                throw new SelectionException(SelectionLayer.Team,
                    $"{Describe(team)} extends '{extends}', which is not attached");
            if (!string.Equals(extends, company.PackageId, StringComparison.OrdinalIgnoreCase))
                throw new SelectionException(SelectionLayer.Team,
                    $"{Describe(team)} extends '{extends}', but the attached company filter is '{company.PackageId}'");
        }

        return (company, team);
    }

    private static void Apply(
        KitCatalog catalog,
        Dictionary<string, PartState> states,
        SelectionLayer layer,
        string who,
        IReadOnlyList<string> enable,
        IReadOnlyList<string> disable,
        HashSet<string> locked,
        string? lockOwner)
    {
        var named = new HashSet<string>(StringComparer.Ordinal);
        foreach (var (id, on) in enable.Select(id => (id, true)).Concat(disable.Select(id => (id, false))))
        {
            var part = RequireKnown(catalog, layer, who, id);
            if (!named.Add(id))
                throw new SelectionException(layer, $"{who} lists part '{id}' twice in enable/disable");
            if (locked.Contains(id))
                throw new SelectionException(layer, $"{who} cannot {(on ? "enable" : "disable")} part '{id}': {lockOwner} locked it");
            if (!on && part.Kind == KitPartKind.Required)
                throw new SelectionException(layer, $"{who} cannot disable part '{id}': it is required");

            states[id] = new PartState(part, on, layer, who);
        }
    }

    private static void CloseOverRequires(KitCatalog catalog, Dictionary<string, PartState> states)
    {
        var pending = new Queue<PartState>(catalog.Parts.Select(p => states[p.Id]).Where(s => s.Enabled));
        while (pending.TryDequeue(out var requirer))
        {
            foreach (var id in requirer.Part.Requires)
            {
                var required = states[id];
                if (required.Enabled)
                    continue;
                if (required.Layer != SelectionLayer.Core)
                    throw new SelectionException(
                        (SelectionLayer)Math.Max((int)requirer.Layer, (int)required.Layer),
                        $"part '{requirer.Part.Id}' ({requirer.Who}) requires part '{id}', which {required.Who} disabled");

                var enabled = new PartState(required.Part, true, requirer.Layer, requirer.Who, requirer.Part.Id);
                states[id] = enabled;
                pending.Enqueue(enabled);
            }
        }
    }

    private static KitCatalogPart RequireKnown(KitCatalog catalog, SelectionLayer layer, string who, string id) =>
        catalog.Find(id) ?? throw new SelectionException(layer, $"{who} names unknown part '{id}'");

    private static string Describe(AttachedFilter filter) =>
        $"the {KitDocumentFormat.TierName(filter.Filter.Tier)} filter '{filter.PackageId}'";

    private sealed record PartState(KitCatalogPart Part, bool Enabled, SelectionLayer Layer, string Who, string? RequiredBy = null);
}

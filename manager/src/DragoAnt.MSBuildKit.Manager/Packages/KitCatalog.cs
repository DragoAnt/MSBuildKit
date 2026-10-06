namespace DragoAnt.MSBuildKit.Manager.Packages;

/// <summary><c>mskit/catalog.json</c> in the trunk package: every core part, ordered by <see cref="KitCatalogPart.Order"/>.</summary>
internal sealed class KitCatalog
{
    public const string PackagePath = "mskit/catalog.json";
    public const int Schema = 1;

    private readonly Dictionary<string, KitCatalogPart> _byId = new(StringComparer.Ordinal);

    public KitCatalog(IEnumerable<KitCatalogPart> parts)
    {
        Parts = [.. parts.OrderBy(p => p.Order).ThenBy(p => p.Id, StringComparer.Ordinal)];
        foreach (var part in Parts)
        {
            if (!_byId.TryAdd(part.Id, part))
                throw new KitDocumentException(PackagePath, $"part '{part.Id}' is listed twice");
        }

        foreach (var part in Parts)
        foreach (var required in part.Requires)
        {
            if (!_byId.ContainsKey(required))
                throw new KitDocumentException(PackagePath, $"part '{part.Id}' requires unknown part '{required}'");
        }
    }

    public IReadOnlyList<KitCatalogPart> Parts { get; }

    public KitCatalogPart? Find(string id) => _byId.GetValueOrDefault(id);

    public static KitCatalog Parse(string json)
    {
        var root = KitDocumentFormat.ReadRoot(PackagePath, json);
        KitDocumentFormat.RequireSchema(PackagePath, root, Schema);
        var dto = KitDocumentFormat.Deserialize<Dto>(PackagePath, root);
        if (dto.Parts is null)
            throw new KitDocumentException(PackagePath, "parts is missing");

        return new KitCatalog(dto.Parts.Select(p => new KitCatalogPart(
            KitDocumentFormat.Required(PackagePath, p.Id, "a part's id"),
            ParseKind(p.Kind, p.Id!),
            p.Order ?? throw new KitDocumentException(PackagePath, $"part '{p.Id}' has no order"),
            p.Requires ?? [])));
    }

    private static KitPartKind ParseKind(string? kind, string id) => kind switch
    {
        "required" => KitPartKind.Required,
        "default" => KitPartKind.Default,
        "optional" => KitPartKind.Optional,
        _ => throw new KitDocumentException(PackagePath, $"part '{id}' has unknown kind '{kind}' (expected required, default or optional)"),
    };

    private sealed class Dto
    {
        public int? Schema { get; init; }
        public PartDto[]? Parts { get; init; }
    }

    private sealed class PartDto
    {
        public string? Id { get; init; }
        public string? Kind { get; init; }
        public int? Order { get; init; }
        public string[]? Requires { get; init; }
    }
}

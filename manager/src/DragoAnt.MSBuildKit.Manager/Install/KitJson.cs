using DragoAnt.MSBuildKit.Manager.Packages;

namespace DragoAnt.MSBuildKit.Manager.Install;

/// <summary>
/// <c>&lt;kit&gt;/kit.json</c>: the repository layer of the selection. Reads schema 2 and the schema 1 that <c>update.sh</c>
/// writes (its <c>parts</c> become enabled parts); always writes schema 2.
/// </summary>
internal sealed record KitJson(IReadOnlyList<KitJsonFilter> Filters, PartToggles Parts, bool Prerelease, KitSourceKind Source)
{
    public const int CurrentSchema = 2;
    private const string Document = KitLayout.KitJsonFileName;
    private static readonly string[] Schema1Fields = ["repository", "version", "sha256", "parts"];

    public static KitJson Empty { get; } = new([], PartToggles.Empty, false, KitSourceKind.Feed);

    /// <summary>The schema the document was read from; 2 for a new one.</summary>
    public int ReadSchema { get; init; } = CurrentSchema;

    /// <summary>The schema-1 fields, when the document was schema 1.</summary>
    public KitJsonLegacy? Legacy { get; init; }

    public static KitJson Parse(string json)
    {
        var root = KitDocumentFormat.ReadRoot(Document, json, lenient: true);
        var schema = KitDocumentFormat.ReadSchema(Document, root);
        if (schema is null && Schema1Fields.Any(f => root.TryGetProperty(f, out _)))
            return ParseSchema1(root);

        KitDocumentFormat.RequireSchema(Document, root, CurrentSchema);
        var dto = KitDocumentFormat.Deserialize<Dto>(Document, root);

        var filters = (dto.Filters ?? []).Select(f => new KitJsonFilter(
            KitDocumentFormat.Required(Document, f.Package, "a filter's package"),
            string.IsNullOrWhiteSpace(f.Source) ? null : f.Source)).ToList();
        var parts = new PartToggles(dto.Parts?.Enable ?? [], dto.Parts?.Disable ?? []);
        KitDocumentFormat.RequireDisjoint(Document, parts.Enable, parts.Disable);
        var source = dto.Source switch
        {
            null or "feed" => KitSourceKind.Feed,
            "local" => KitSourceKind.Local,
            _ => throw new KitDocumentException(Document, $"unknown source '{dto.Source}' (expected feed or local)"),
        };

        return new KitJson(filters, parts, dto.Prerelease ?? false, source);
    }

    public string ToJson() => KitDocumentFormat.Write(writer =>
    {
        writer.WriteStartObject();
        writer.WriteNumber("schema", CurrentSchema);
        writer.WriteStartArray("filters");
        foreach (var filter in Filters)
        {
            writer.WriteStartObject();
            writer.WriteString("package", filter.Package);
            if (filter.Source is not null)
                writer.WriteString("source", filter.Source);
            writer.WriteEndObject();
        }

        writer.WriteEndArray();
        writer.WriteStartObject("parts");
        KitDocumentFormat.WriteStringArray(writer, "enable", Parts.Enable);
        KitDocumentFormat.WriteStringArray(writer, "disable", Parts.Disable);
        writer.WriteEndObject();
        writer.WriteBoolean("prerelease", Prerelease);
        writer.WriteString("source", Source == KitSourceKind.Local ? "local" : "feed");
        writer.WriteEndObject();
    });

    private static KitJson ParseSchema1(System.Text.Json.JsonElement root)
    {
        var dto = KitDocumentFormat.Deserialize<Schema1Dto>(Document, root);
        return Empty with
        {
            Parts = new PartToggles(dto.Parts ?? [], []),
            ReadSchema = 1,
            Legacy = new KitJsonLegacy(dto.Repository, dto.Version, dto.Sha256),
        };
    }

    private sealed class Dto
    {
        public int? Schema { get; init; }
        public FilterDto[]? Filters { get; init; }
        public PartsDto? Parts { get; init; }
        public bool? Prerelease { get; init; }
        public string? Source { get; init; }
    }

    private sealed class FilterDto
    {
        public string? Package { get; init; }
        public string? Source { get; init; }
    }

    private sealed class PartsDto
    {
        public string[]? Enable { get; init; }
        public string[]? Disable { get; init; }
    }

    private sealed class Schema1Dto
    {
        public string? Repository { get; init; }
        public string? Version { get; init; }
        public string? Sha256 { get; init; }
        public string[]? Parts { get; init; }
    }
}

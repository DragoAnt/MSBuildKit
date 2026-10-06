namespace DragoAnt.MSBuildKit.Manager.Packages;

/// <summary><c>mskit.package.json</c>: what makes a NuGet package a kit package.</summary>
internal sealed record KitPackageMetadata(string Id, KitTier Tier, int Order, string? ContentHash)
{
    public const string PackagePath = "mskit.package.json";
    public const int Schema = 1;

    public static KitPackageMetadata Parse(string json)
    {
        var root = KitDocumentFormat.ReadRoot(PackagePath, json);
        KitDocumentFormat.RequireSchema(PackagePath, root, Schema);
        var dto = KitDocumentFormat.Deserialize<Dto>(PackagePath, root);

        return new KitPackageMetadata(
            KitDocumentFormat.Required(PackagePath, dto.Id, "id"),
            KitDocumentFormat.ParseTier(PackagePath, dto.Tier),
            dto.Order ?? throw new KitDocumentException(PackagePath, "order is missing"),
            string.IsNullOrEmpty(dto.ContentHash) ? null : dto.ContentHash);
    }

    public string ToJson() => KitDocumentFormat.Write(writer =>
    {
        writer.WriteStartObject();
        writer.WriteNumber("schema", Schema);
        writer.WriteString("id", Id);
        writer.WriteString("tier", KitDocumentFormat.TierName(Tier));
        writer.WriteNumber("order", Order);
        if (ContentHash is not null)
            writer.WriteString("contentHash", ContentHash);
        writer.WriteEndObject();
    });

    private sealed class Dto
    {
        public int? Schema { get; init; }
        public string? Id { get; init; }
        public string? Tier { get; init; }
        public int? Order { get; init; }
        public string? ContentHash { get; init; }
    }
}

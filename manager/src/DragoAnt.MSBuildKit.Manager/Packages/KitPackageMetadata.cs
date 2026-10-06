using System.Text.Json;
using NuGet.Versioning;

namespace DragoAnt.MSBuildKit.Manager.Packages;

/// <summary>
/// <c>mskit.package.json</c> at the package root: what makes a NuGet package a kit package.
/// <see cref="Umbrella"/> marks a package that only pins other kit packages; <see cref="Tool"/> is the lowest
/// <c>mskit-manager</c> version the package needs.
/// </summary>
internal sealed record KitPackageMetadata(string Id, int Order, bool Umbrella, string? ContentHash, string? Tool)
{
    public const string PackagePath = "mskit.package.json";
    public const int Schema = 1;
    public const int DefaultOrder = 1000;

    public static KitPackageMetadata Parse(string json)
    {
        var root = KitDocumentFormat.ReadRoot(PackagePath, json);
        KitDocumentFormat.RequireSchema(PackagePath, root, Schema);
        var dto = KitDocumentFormat.Deserialize<Dto>(PackagePath, root);

        return new KitPackageMetadata(
            KitDocumentFormat.Required(PackagePath, dto.Id, "id"),
            dto.Order ?? DefaultOrder,
            dto.Umbrella ?? false,
            string.IsNullOrEmpty(dto.ContentHash) ? null : dto.ContentHash,
            dto.Tool is null ? null : RequireVersion(dto.Tool));
    }

    public string ToJson() => KitDocumentFormat.Write(writer =>
    {
        writer.WriteStartObject();
        writer.WriteNumber("schema", Schema);
        writer.WriteString("id", Id);
        writer.WriteNumber("order", Order);
        if (Umbrella)
            writer.WriteBoolean("umbrella", true);
        if (ContentHash is not null)
            writer.WriteString("contentHash", ContentHash);
        if (Tool is not null)
            writer.WriteString("tool", Tool);
        writer.WriteEndObject();
    });

    private static string RequireVersion(string tool) => NuGetVersion.TryParse(tool, out _)
        ? tool
        : throw new KitDocumentException(PackagePath, $"tool '{tool}' is not a NuGet version");

    private sealed class Dto
    {
        public int? Schema { get; init; }
        public string? Id { get; init; }
        public int? Order { get; init; }
        public bool? Umbrella { get; init; }
        public string? ContentHash { get; init; }
        public string? Tool { get; init; }

        // No longer part of the marker; accepted and ignored so the strict reader does not reject it.
        public JsonElement? Tier { get; init; }
    }
}

using DragoAnt.MSBuildKit.Manager.Packages;

namespace DragoAnt.MSBuildKit.Manager.Install;

/// <summary>
/// The schema-1 <c>&lt;kit&gt;/kit.json</c> that <c>update.sh</c> writes beside a zip-installed kit: read once, to migrate
/// that kit to packages. A <c>parts</c> array spread over several lines is read like a single-line one.
/// </summary>
internal sealed record LegacyKitJson(string? Repository, string? Version, string? Sha256, IReadOnlyList<string> Parts)
{
    private const string Document = KitLayout.LegacyKitJsonFileName;
    private static readonly string[] Fields = ["repository", "version", "sha256", "parts"];

    public static LegacyKitJson Parse(string json)
    {
        var root = KitDocumentFormat.ReadRoot(Document, json, lenient: true);
        if (root.TryGetProperty("schema", out _) || !Fields.Any(f => root.TryGetProperty(f, out _)))
            throw new KitDocumentException(Document, "not a kit.json written by update.sh");

        var dto = KitDocumentFormat.Deserialize<Dto>(Document, root);
        return new LegacyKitJson(dto.Repository, dto.Version, dto.Sha256, dto.Parts ?? []);
    }

    private sealed class Dto
    {
        public string? Repository { get; init; }
        public string? Version { get; init; }
        public string? Sha256 { get; init; }
        public string[]? Parts { get; init; }
    }
}

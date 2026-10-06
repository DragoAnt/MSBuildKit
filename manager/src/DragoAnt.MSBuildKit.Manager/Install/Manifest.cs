using DragoAnt.MSBuildKit.Manager.Packages;

namespace DragoAnt.MSBuildKit.Manager.Install;

/// <summary>
/// <c>&lt;kit&gt;/.manager/manifest.json</c>: every file the last install deployed and its SHA-256 — the source of
/// orphan removal and <c>verify</c> — and where the packages came from. Written sorted, indented, LF-only, so it
/// round-trips byte for byte; <c>source</c> is written only when it is <c>local</c>.
/// </summary>
internal sealed record Manifest(
    IReadOnlyList<ManifestPackage> Packages,
    IReadOnlyList<ManifestFile> Files,
    KitSourceKind Source = KitSourceKind.Feed)
{
    public const int Schema = 1;
    private const string Document = KitLayout.ManifestFileName;

    public static Manifest Parse(string json)
    {
        var root = KitDocumentFormat.ReadRoot(Document, json);
        KitDocumentFormat.RequireSchema(Document, root, Schema);
        var dto = KitDocumentFormat.Deserialize<Dto>(Document, root);

        var packageIds = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var packages = (dto.Packages ?? []).Select(p =>
        {
            var id = KitDocumentFormat.Required(Document, p.Id, "a package's id");
            if (!packageIds.Add(id))
                throw new KitDocumentException(Document, $"package '{id}' is listed twice");
            return new ManifestPackage(id, KitDocumentFormat.Required(Document, p.Version, $"package '{id}' version"));
        }).ToList();

        var paths = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        var files = (dto.Files ?? []).Select(f =>
        {
            var path = KitDocumentFormat.Required(Document, f.Path, "a file's path");
            if (path.Contains('\\') || path.StartsWith('/') || path.Contains(':') || path.Split('/').Any(s => s is "" or "." or ".."))
                throw new KitDocumentException(Document, $"file path '{path}' is not a relative forward-slash path inside the kit folder");
            if (!paths.Add(path))
                throw new KitDocumentException(Document, $"file '{path}' is listed twice");
            var sha256 = f.Sha256 ?? string.Empty;
            if (sha256.Length != 64 || !sha256.All(char.IsAsciiHexDigitLower))
                throw new KitDocumentException(Document, $"file '{path}' has sha256 '{sha256}', expected 64 lowercase hex digits");
            if (f.Package is not null && !packageIds.Contains(f.Package))
                throw new KitDocumentException(Document, $"file '{path}' names package '{f.Package}', which is not listed");
            return new ManifestFile(path, f.Package, sha256);
        }).ToList();

        var source = dto.Source switch
        {
            null or "feed" => KitSourceKind.Feed,
            "local" => KitSourceKind.Local,
            _ => throw new KitDocumentException(Document, $"unknown source '{dto.Source}' (expected feed or local)"),
        };

        return new Manifest(packages, files, source);
    }

    public string ToJson() => KitDocumentFormat.Write(writer =>
    {
        writer.WriteStartObject();
        writer.WriteNumber("schema", Schema);
        if (Source == KitSourceKind.Local)
            writer.WriteString("source", "local");
        writer.WriteStartArray("packages");
        foreach (var package in Packages.OrderBy(p => p.Id, StringComparer.Ordinal))
        {
            writer.WriteStartObject();
            writer.WriteString("id", package.Id);
            writer.WriteString("version", package.Version);
            writer.WriteEndObject();
        }

        writer.WriteEndArray();
        writer.WriteStartArray("files");
        foreach (var file in Files.OrderBy(f => f.Path, StringComparer.Ordinal))
        {
            writer.WriteStartObject();
            writer.WriteString("path", file.Path);
            writer.WriteString("package", file.Package);
            writer.WriteString("sha256", file.Sha256);
            writer.WriteEndObject();
        }

        writer.WriteEndArray();
        writer.WriteEndObject();
    });

    private sealed class Dto
    {
        public int? Schema { get; init; }
        public string? Source { get; init; }
        public PackageDto[]? Packages { get; init; }
        public FileDto[]? Files { get; init; }
    }

    private sealed class PackageDto
    {
        public string? Id { get; init; }
        public string? Version { get; init; }
    }

    private sealed class FileDto
    {
        public string? Path { get; init; }
        public string? Package { get; init; }
        public string? Sha256 { get; init; }
    }
}

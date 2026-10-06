using NuGet.Versioning;

namespace DragoAnt.MSBuildKit.Manager.Packages;

/// <summary><c>mskit/filter.json</c> in a company or team package.</summary>
internal sealed record KitFilter(
    KitTier Tier,
    string Name,
    string? Extends,
    IReadOnlyList<KitFilterSource> Sources,
    IReadOnlyList<KitFilterPackage> Packages,
    KitFilterParts Parts,
    KitFilterCore? Core)
{
    public const string PackagePath = "mskit/filter.json";
    public const int Schema = 1;

    public static KitFilter Parse(string json)
    {
        var root = KitDocumentFormat.ReadRoot(PackagePath, json);
        KitDocumentFormat.RequireSchema(PackagePath, root, Schema);
        var dto = KitDocumentFormat.Deserialize<Dto>(PackagePath, root);

        var tier = KitDocumentFormat.ParseTier(PackagePath, dto.Tier);
        var name = KitDocumentFormat.Required(PackagePath, dto.Name, "name");
        var extends = string.IsNullOrWhiteSpace(dto.Extends) ? null : dto.Extends;
        switch (tier)
        {
            case KitTier.Core:
                throw new KitDocumentException(PackagePath, "a filter's tier is company or team, not core");
            case KitTier.Team when extends is null:
                throw new KitDocumentException(PackagePath, "a team filter names the company package it extends");
            case KitTier.Company when extends is not null:
                throw new KitDocumentException(PackagePath, $"a company filter extends nothing, found extends '{extends}'");
        }

        var parts = new KitFilterParts(dto.Parts?.Enable ?? [], dto.Parts?.Disable ?? [], dto.Parts?.Locked ?? []);
        KitDocumentFormat.RequireDisjoint(PackagePath, parts.Enable, parts.Disable);
        if (tier == KitTier.Team && parts.Locked.Count > 0)
            throw new KitDocumentException(PackagePath, "only a company filter may list locked parts");

        var sources = (dto.Sources ?? []).Select(s =>
        {
            var sourceName = KitDocumentFormat.Required(PackagePath, s.Name, "a source's name");
            var url = KitDocumentFormat.Required(PackagePath, s.Url, $"source '{sourceName}' url");
            if (s.Patterns is not { Length: > 0 })
                throw new KitDocumentException(PackagePath, $"source '{sourceName}' has no patterns");
            return new KitFilterSource(sourceName, url, s.Patterns);
        }).ToList();

        var packages = (dto.Packages ?? []).Select(p =>
        {
            var id = KitDocumentFormat.Required(PackagePath, p.Id, "a package's id");
            return new KitFilterPackage(id, RequireRange(p.Version, $"package '{id}'"));
        }).ToList();

        var core = dto.Core is null ? null : new KitFilterCore(RequireRange(dto.Core.Version, "core"), dto.Core.Prerelease);

        return new KitFilter(tier, name, extends, sources, packages, parts, core);
    }

    private static string? RequireRange(string? version, string owner)
    {
        if (string.IsNullOrWhiteSpace(version))
            return null;
        return VersionRange.TryParse(version, out _)
            ? version
            : throw new KitDocumentException(PackagePath, $"{owner} version '{version}' is not a NuGet version range");
    }

    private sealed class Dto
    {
        public int? Schema { get; init; }
        public string? Tier { get; init; }
        public string? Name { get; init; }
        public string? Extends { get; init; }
        public SourceDto[]? Sources { get; init; }
        public PackageDto[]? Packages { get; init; }
        public PartsDto? Parts { get; init; }
        public CoreDto? Core { get; init; }
    }

    private sealed class SourceDto
    {
        public string? Name { get; init; }
        public string? Url { get; init; }
        public string[]? Patterns { get; init; }
    }

    private sealed class PackageDto
    {
        public string? Id { get; init; }
        public string? Version { get; init; }
    }

    private sealed class PartsDto
    {
        public string[]? Enable { get; init; }
        public string[]? Disable { get; init; }
        public string[]? Locked { get; init; }
    }

    private sealed class CoreDto
    {
        public string? Version { get; init; }
        public bool? Prerelease { get; init; }
    }
}

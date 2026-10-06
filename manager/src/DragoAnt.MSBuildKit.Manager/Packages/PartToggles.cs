namespace DragoAnt.MSBuildKit.Manager.Packages;

/// <summary>The repository layer's part switches, from <c>kit.json</c>.</summary>
internal sealed record PartToggles(IReadOnlyList<string> Enable, IReadOnlyList<string> Disable)
{
    public static PartToggles Empty { get; } = new([], []);
}

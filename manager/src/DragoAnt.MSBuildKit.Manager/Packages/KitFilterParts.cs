namespace DragoAnt.MSBuildKit.Manager.Packages;

/// <summary>The parts a filter switches on or off; <see cref="Locked"/> (company only) freezes them for the later layers.</summary>
internal sealed record KitFilterParts(IReadOnlyList<string> Enable, IReadOnlyList<string> Disable, IReadOnlyList<string> Locked)
{
    public static KitFilterParts Empty { get; } = new([], [], []);
}

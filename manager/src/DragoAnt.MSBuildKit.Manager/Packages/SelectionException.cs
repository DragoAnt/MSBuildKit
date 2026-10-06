namespace DragoAnt.MSBuildKit.Manager.Packages;

/// <summary>A layer asked for a selection the rules refuse; <see cref="Layer"/> names it.</summary>
internal sealed class SelectionException(SelectionLayer layer, string message) : Exception(message)
{
    public SelectionLayer Layer { get; } = layer;
}

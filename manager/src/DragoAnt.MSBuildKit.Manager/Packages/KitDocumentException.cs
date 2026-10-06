namespace DragoAnt.MSBuildKit.Manager.Packages;

/// <summary>A kit document (<c>mskit.package.json</c>, <c>catalog.json</c>, <c>filter.json</c>, <c>kit.json</c>, the manifest) is malformed.</summary>
internal sealed class KitDocumentException(string document, string message) : Exception($"{document}: {message}")
{
    public string Document { get; } = document;
}

namespace DragoAnt.Samples.MinimalLibrary;

/// <summary>Builds greetings.</summary>
public static class Greeter
{
    /// <summary>Returns a greeting for <paramref name="name"/>.</summary>
    /// <param name="name">The name to greet; blank names are greeted as "world".</param>
    /// <returns>The greeting text.</returns>
    public static string Greet(string? name) => $"Hello, {(string.IsNullOrWhiteSpace(name) ? "world" : name.Trim())}!";

    internal static int Length(string text) => text.Length;
}

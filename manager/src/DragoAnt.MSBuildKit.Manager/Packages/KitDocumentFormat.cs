using System.Text;
using System.Text.Encodings.Web;
using System.Text.Json;

namespace DragoAnt.MSBuildKit.Manager.Packages;

/// <summary>Reading and writing the kit's JSON documents: one strict reader, one LF-only indented writer.</summary>
internal static class KitDocumentFormat
{
    private static readonly JsonSerializerOptions ReadOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        UnmappedMemberHandling = System.Text.Json.Serialization.JsonUnmappedMemberHandling.Disallow,
        // ReadRoot already applied the document's strictness; a lenient root's raw text still carries its comments.
        ReadCommentHandling = JsonCommentHandling.Skip,
        AllowTrailingCommas = true,
    };

    private static readonly JsonWriterOptions WriteOptions = new()
    {
        Indented = true,
        Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
    };

    /// <summary>Parses <paramref name="json"/> and returns its root object; <paramref name="lenient"/> allows comments and trailing commas.</summary>
    public static JsonElement ReadRoot(string document, string json, bool lenient = false)
    {
        try
        {
            using var parsed = JsonDocument.Parse(json, new JsonDocumentOptions
            {
                CommentHandling = lenient ? JsonCommentHandling.Skip : JsonCommentHandling.Disallow,
                AllowTrailingCommas = lenient,
            });
            if (parsed.RootElement.ValueKind != JsonValueKind.Object)
                throw new KitDocumentException(document, $"expected a JSON object, found {parsed.RootElement.ValueKind}");
            return parsed.RootElement.Clone();
        }
        catch (JsonException ex)
        {
            throw new KitDocumentException(document, ex.Message);
        }
    }

    /// <summary>The <c>schema</c> number of <paramref name="root"/>, or <see langword="null"/> when it has none.</summary>
    public static int? ReadSchema(string document, JsonElement root)
    {
        if (!root.TryGetProperty("schema", out var schema))
            return null;
        if (schema.ValueKind != JsonValueKind.Number || !schema.TryGetInt32(out var value))
            throw new KitDocumentException(document, $"schema must be a number, found {schema}");
        return value;
    }

    public static void RequireSchema(string document, JsonElement root, int expected)
    {
        var schema = ReadSchema(document, root);
        if (schema != expected)
            throw new KitDocumentException(document, schema is null
                ? $"schema is missing (expected {expected})"
                : $"schema {schema} is not supported (expected {expected})");
    }

    public static T Deserialize<T>(string document, JsonElement root)
    {
        try
        {
            return root.Deserialize<T>(ReadOptions) ?? throw new KitDocumentException(document, "the document is empty");
        }
        catch (JsonException ex)
        {
            throw new KitDocumentException(document, ex.Message);
        }
    }

    public static string Required(string document, string? value, string name) =>
        string.IsNullOrWhiteSpace(value) ? throw new KitDocumentException(document, $"{name} is missing") : value;

    public static KitTier ParseTier(string document, string? value) => value switch
    {
        "core" => KitTier.Core,
        "company" => KitTier.Company,
        "team" => KitTier.Team,
        null => throw new KitDocumentException(document, "tier is missing"),
        _ => throw new KitDocumentException(document, $"unknown tier '{value}' (expected core, company or team)"),
    };

    public static string TierName(KitTier tier) => tier switch
    {
        KitTier.Core => "core",
        KitTier.Company => "company",
        _ => "team",
    };

    /// <summary>Throws when a part is listed twice, or in both <paramref name="enable"/> and <paramref name="disable"/>.</summary>
    public static void RequireDisjoint(string document, IReadOnlyList<string> enable, IReadOnlyList<string> disable)
    {
        var seen = new HashSet<string>(StringComparer.Ordinal);
        foreach (var part in enable.Concat(disable))
        {
            if (!seen.Add(part))
                throw new KitDocumentException(document, $"part '{part}' is listed twice in enable/disable");
        }
    }

    /// <summary>Writes an indented document with LF line ends and a final newline, whatever the OS.</summary>
    public static string Write(Action<Utf8JsonWriter> write)
    {
        using var stream = new MemoryStream();
        using (var writer = new Utf8JsonWriter(stream, WriteOptions))
            write(writer);
        return Encoding.UTF8.GetString(stream.ToArray()).Replace("\r\n", "\n", StringComparison.Ordinal) + "\n";
    }

    public static void WriteStringArray(Utf8JsonWriter writer, string name, IEnumerable<string> values)
    {
        writer.WriteStartArray(name);
        foreach (var value in values)
            writer.WriteStringValue(value);
        writer.WriteEndArray();
    }
}

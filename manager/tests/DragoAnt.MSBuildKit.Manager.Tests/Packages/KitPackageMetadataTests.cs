using DragoAnt.MSBuildKit.Manager.Packages;

namespace DragoAnt.MSBuildKit.Manager.Tests.Packages;

public sealed class KitPackageMetadataTests
{
    // language=json
    private const string Canonical = """
        {
          "schema": 1,
          "id": "Contoso.MSBuildKit",
          "order": 120,
          "umbrella": true,
          "contentHash": "sha256:3f6c",
          "tool": "0.3.0-beta.1"
        }

        """;

    [Fact]
    public void Parse_ReadsEveryField()
    {
        var metadata = KitPackageMetadata.Parse(Canonical);

        metadata.Should().Be(new KitPackageMetadata("Contoso.MSBuildKit", 120, true, "sha256:3f6c", "0.3.0-beta.1"));
    }

    [Fact]
    public void Parse_OnlyTheRequiredFields_UsesDefaults()
    {
        var metadata = KitPackageMetadata.Parse("""{ "schema": 1, "id": "DragoAnt.MSBuildKit.Testing" }""");

        metadata.Order.Should().Be(KitPackageMetadata.DefaultOrder).And.Be(1000);
        metadata.Umbrella.Should().BeFalse();
        metadata.ContentHash.Should().BeNull();
        metadata.Tool.Should().BeNull();
    }

    [Fact]
    public void Parse_TierField_IsIgnored()
    {
        var metadata = KitPackageMetadata.Parse("""{ "schema": 1, "id": "Contoso.MSBuildKit", "tier": "company", "order": 0 }""");

        metadata.Should().Be(new KitPackageMetadata("Contoso.MSBuildKit", 0, false, null, null));
    }

    [Fact]
    public void ToJson_RoundTrips_ByteStable()
    {
        var text = Canonical.ReplaceLineEndings("\n");

        var once = KitPackageMetadata.Parse(text).ToJson();

        once.Should().Be(text);
        KitPackageMetadata.Parse(once).ToJson().Should().Be(once);
    }

    [Fact]
    public void ToJson_OmitsDefaultUmbrellaAndAbsentOptionals()
    {
        var json = new KitPackageMetadata("Contoso.MSBuildKit", 1000, false, null, null).ToJson();

        json.Should().Be("{\n  \"schema\": 1,\n  \"id\": \"Contoso.MSBuildKit\",\n  \"order\": 1000\n}\n");
    }

    [Theory]
    [InlineData("""{ "schema": 2, "id": "A" }""", "schema")]
    [InlineData("""{ "id": "A" }""", "schema")]
    [InlineData("""{ "schema": 1, "order": 1 }""", "id")]
    [InlineData("""{ "schema": 1, "id": "A", "tool": "x" }""", "'x'")]
    [InlineData("""{ "schema": 1, "id": "A", "tool": "" }""", "tool")]
    [InlineData("""{ "schema": 1, "id": "A", "order": 1, "extra": true }""", "extra")]
    [InlineData("""not json""", KitPackageMetadata.PackagePath)]
    public void Parse_InvalidDocument_Throws(string json, string mentioned)
    {
        var act = () => KitPackageMetadata.Parse(json);

        act.Should().Throw<KitDocumentException>()
            .Which.Message.Should().Contain(KitPackageMetadata.PackagePath).And.Contain(mentioned);
    }
}

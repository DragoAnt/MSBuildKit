using DragoAnt.MSBuildKit.Manager.Packages;

namespace DragoAnt.MSBuildKit.Manager.Tests.Packages;

public sealed class KitPackageMetadataTests
{
    [Fact]
    public void Parse_ReadsEveryField()
    {
        // language=json
        const string json = """
            {
              "schema": 1,
              "id": "DragoAnt.MSBuildKit.Testing",
              "tier": "core",
              "order": 120,
              "contentHash": "sha256:3f6c"
            }
            """;

        var metadata = KitPackageMetadata.Parse(json);

        metadata.Should().Be(new KitPackageMetadata("DragoAnt.MSBuildKit.Testing", KitTier.Core, 120, "sha256:3f6c"));
    }

    [Fact]
    public void Parse_WithoutContentHash_LeavesItNull()
    {
        var metadata = KitPackageMetadata.Parse("""{ "schema": 1, "id": "Contoso.MSBuildKit", "tier": "company", "order": 0 }""");

        metadata.ContentHash.Should().BeNull();
        metadata.Tier.Should().Be(KitTier.Company);
    }

    [Fact]
    public void ToJson_RoundTrips()
    {
        var metadata = new KitPackageMetadata("Contoso.Web.MSBuildKit", KitTier.Team, 7, "sha256:00");

        KitPackageMetadata.Parse(metadata.ToJson()).Should().Be(metadata);
    }

    [Theory]
    [InlineData("""{ "schema": 2, "id": "A", "tier": "core", "order": 1 }""", "schema")]
    [InlineData("""{ "id": "A", "tier": "core", "order": 1 }""", "schema")]
    [InlineData("""{ "schema": 1, "tier": "core", "order": 1 }""", "id")]
    [InlineData("""{ "schema": 1, "id": "A", "tier": "galaxy", "order": 1 }""", "galaxy")]
    [InlineData("""{ "schema": 1, "id": "A", "tier": "core" }""", "order")]
    [InlineData("""{ "schema": 1, "id": "A", "tier": "core", "order": 1, "extra": true }""", "extra")]
    [InlineData("""not json""", KitPackageMetadata.PackagePath)]
    public void Parse_InvalidDocument_Throws(string json, string mentioned)
    {
        var act = () => KitPackageMetadata.Parse(json);

        act.Should().Throw<KitDocumentException>()
            .Which.Message.Should().Contain(KitPackageMetadata.PackagePath).And.Contain(mentioned);
    }
}

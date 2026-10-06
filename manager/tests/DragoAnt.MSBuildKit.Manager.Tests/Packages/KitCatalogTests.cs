using DragoAnt.MSBuildKit.Manager.Packages;

namespace DragoAnt.MSBuildKit.Manager.Tests.Packages;

public sealed class KitCatalogTests
{
    [Fact]
    public void Parse_ReadsThePartsInOrder()
    {
        // language=json
        const string json = """
            {
              "schema": 1,
              "parts": [
                { "id": "Project.CodeAnalyzer", "kind": "optional", "order": 210, "requires": [ "Project.RoslynComponent" ] },
                { "id": "Core", "kind": "required", "order": 0 },
                { "id": "Project.RoslynComponent", "kind": "optional", "order": 200, "requires": [] },
                { "id": "Testing", "kind": "default", "order": 120 }
              ]
            }
            """;

        var catalog = KitCatalog.Parse(json);

        catalog.Parts.Select(p => p.Id).Should().Equal("Core", "Testing", "Project.RoslynComponent", "Project.CodeAnalyzer");
        catalog.Find("Project.CodeAnalyzer")!.Requires.Should().Equal("Project.RoslynComponent");
        catalog.Find("Core")!.Kind.Should().Be(KitPartKind.Required);
        catalog.Find("Testing")!.Kind.Should().Be(KitPartKind.Default);
        catalog.Find("Core")!.Requires.Should().BeEmpty();
        catalog.Find("Missing").Should().BeNull();
    }

    [Theory]
    [InlineData("""{ "schema": 1, "parts": [ { "id": "A", "kind": "default", "order": 1 }, { "id": "A", "kind": "optional", "order": 2 } ] }""", "'A'")]
    [InlineData("""{ "schema": 1, "parts": [ { "id": "A", "kind": "default", "order": 1, "requires": [ "B" ] } ] }""", "'B'")]
    [InlineData("""{ "schema": 1, "parts": [ { "id": "A", "kind": "sometimes", "order": 1 } ] }""", "sometimes")]
    [InlineData("""{ "schema": 1, "parts": [ { "kind": "default", "order": 1 } ] }""", "id")]
    [InlineData("""{ "schema": 1 }""", "parts")]
    [InlineData("""{ "schema": 3, "parts": [] }""", "schema")]
    public void Parse_InvalidDocument_Throws(string json, string mentioned)
    {
        var act = () => KitCatalog.Parse(json);

        act.Should().Throw<KitDocumentException>()
            .Which.Message.Should().Contain(KitCatalog.PackagePath).And.Contain(mentioned);
    }
}

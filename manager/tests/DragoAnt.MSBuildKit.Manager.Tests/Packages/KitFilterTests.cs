using DragoAnt.MSBuildKit.Manager.Packages;

namespace DragoAnt.MSBuildKit.Manager.Tests.Packages;

public sealed class KitFilterTests
{
    [Fact]
    public void Parse_CompanyFilter_ReadsEverySection()
    {
        // language=json
        const string json = """
            {
              "schema": 1,
              "tier": "company",
              "name": "contoso",
              "sources": [
                { "name": "contoso", "url": "https://packages.contoso.example/api/v3/index.json", "patterns": [ "Contoso.*" ] }
              ],
              "packages": [
                { "id": "Contoso.MSBuildKit.Signing", "version": "[1.2.0, 2.0.0)" }
              ],
              "parts": {
                "enable": [ "Vcs.GitLab", "EF" ],
                "disable": [ "Vcs.GitHub" ],
                "locked": [ "Locals.Secrets" ]
              },
              "core": { "version": "[0.3.0, 1.0.0)", "prerelease": false }
            }
            """;

        var filter = KitFilter.Parse(json);

        filter.Tier.Should().Be(KitTier.Company);
        filter.Name.Should().Be("contoso");
        filter.Extends.Should().BeNull();
        filter.Sources.Should().ContainSingle().Which.Should().BeEquivalentTo(
            new KitFilterSource("contoso", "https://packages.contoso.example/api/v3/index.json", ["Contoso.*"]));
        filter.Packages.Should().ContainSingle().Which.Should().Be(new KitFilterPackage("Contoso.MSBuildKit.Signing", "[1.2.0, 2.0.0)"));
        filter.Parts.Enable.Should().Equal("Vcs.GitLab", "EF");
        filter.Parts.Disable.Should().Equal("Vcs.GitHub");
        filter.Parts.Locked.Should().Equal("Locals.Secrets");
        filter.Core.Should().Be(new KitFilterCore("[0.3.0, 1.0.0)", false));
    }

    [Fact]
    public void Parse_TeamFilter_KeepsExtendsAndDefaultsTheRest()
    {
        var filter = KitFilter.Parse("""{ "schema": 1, "tier": "team", "name": "web", "extends": "Contoso.MSBuildKit" }""");

        filter.Tier.Should().Be(KitTier.Team);
        filter.Extends.Should().Be("Contoso.MSBuildKit");
        filter.Sources.Should().BeEmpty();
        filter.Packages.Should().BeEmpty();
        filter.Parts.Enable.Should().BeEmpty();
        filter.Parts.Locked.Should().BeEmpty();
        filter.Core.Should().BeNull();
    }

    [Theory]
    [InlineData("""{ "schema": 1, "tier": "core", "name": "x" }""", "core")]
    [InlineData("""{ "schema": 1, "tier": "team", "name": "web" }""", "extends")]
    [InlineData("""{ "schema": 1, "tier": "company", "name": "x", "extends": "Other.MSBuildKit" }""", "extends")]
    [InlineData("""{ "schema": 1, "tier": "team", "name": "web", "extends": "C.MSBuildKit", "parts": { "locked": [ "EF" ] } }""", "locked")]
    [InlineData("""{ "schema": 1, "tier": "company" }""", "name")]
    [InlineData("""{ "schema": 1, "tier": "company", "name": "x", "packages": [ { "id": "C.MSBuildKit.A", "version": "not a range" } ] }""", "not a range")]
    [InlineData("""{ "schema": 1, "tier": "company", "name": "x", "core": { "version": "[1.0" } }""", "[1.0")]
    [InlineData("""{ "schema": 1, "tier": "company", "name": "x", "sources": [ { "name": "s", "patterns": [ "C.*" ] } ] }""", "url")]
    [InlineData("""{ "schema": 1, "tier": "company", "name": "x", "sources": [ { "name": "s", "url": "https://x.example/index.json", "patterns": [] } ] }""", "patterns")]
    [InlineData("""{ "schema": 1, "tier": "company", "name": "x", "parts": { "enable": [ "EF" ], "disable": [ "EF" ] } }""", "'EF'")]
    [InlineData("""{ "schema": 1, "tier": "company", "name": "x", "properties": { "A": "1" } }""", "properties")]
    public void Parse_InvalidDocument_Throws(string json, string mentioned)
    {
        var act = () => KitFilter.Parse(json);

        act.Should().Throw<KitDocumentException>()
            .Which.Message.Should().Contain(KitFilter.PackagePath).And.Contain(mentioned);
    }
}
